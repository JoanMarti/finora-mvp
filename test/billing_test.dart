import 'dart:async';

import 'package:finora/app/theme.dart';
import 'package:finora/application/backend.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/data/billing/play_purchase_service.dart';
import 'package:finora/domain/purchases.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const _monthly = StoreOffer(
  period: BillingPeriod.monthly,
  formattedPrice: 'CHF 6.90',
  handle: 'monthly',
);
const _yearly = StoreOffer(
  period: BillingPeriod.yearly,
  formattedPrice: 'CHF 59.00',
  handle: 'yearly',
);
const _yearlyTrial = StoreOffer(
  period: BillingPeriod.yearly,
  formattedPrice: 'CHF 59.00',
  freeTrialDays: 14,
  handle: 'yearly-trial',
);

/// Answers a purchase with [outcome]; remembers what was bought.
class _FakePort implements BillingPort {
  _FakePort({
    this.outcome = StorePurchaseState.purchased,
    this.owned = const [],
  });

  final StorePurchaseState outcome;
  final List<StorePurchase> owned;
  final _updates = StreamController<List<StorePurchase>>.broadcast();
  StoreOffer? bought;
  final acknowledged = <StorePurchase>[];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreOffer>> offers(String productId) async => const [
    _monthly,
    _yearly,
    _yearlyTrial,
  ];

  @override
  Future<void> buy(StoreOffer offer) async {
    bought = offer;
    scheduleMicrotask(
      () => _updates.add([
        StorePurchase(
          productId: 'finora_premium',
          state: outcome,
          date: DateTime(2026, 10, 23),
          receipt: 'token-1',
          needsAcknowledgement: true,
        ),
      ]),
    );
  }

  @override
  Future<void> restore() async {
    scheduleMicrotask(() => _updates.add(owned));
  }

  @override
  Future<void> acknowledge(StorePurchase purchase) async =>
      acknowledged.add(purchase);

  @override
  Stream<List<StorePurchase>> get updates => _updates.stream;
}

PlayPurchaseService _service(_FakePort port, {PurchaseVerifier? verify}) =>
    PlayPurchaseService(
      port,
      verify: verify,
      restoreWindow: const Duration(milliseconds: 20),
    );

class _Store implements PurchaseService {
  _Store(this.restoreResult);
  final PurchaseResult restoreResult;

  @override
  bool get isStore => true;

  @override
  Future<PurchaseResult> buyPlus({
    BillingPeriod period = BillingPeriod.yearly,
    bool withTrial = false,
  }) async => const PurchaseResult(PurchaseStatus.cancelled);

  @override
  Future<PurchaseResult> restore() async => restoreResult;

  @override
  Future<Map<BillingPeriod, StorePrice>> prices() async => const {
    BillingPeriod.yearly: StorePrice(
      period: BillingPeriod.yearly,
      formattedPrice: 'CHF 59.00',
      freeTrialDays: 14,
    ),
  };
}

void main() {
  group('Google Play Billing', () {
    test('prices come from the base plans, with the trial length', () async {
      final prices = await _service(_FakePort()).prices();
      expect(prices[BillingPeriod.yearly]?.formattedPrice, 'CHF 59.00');
      expect(prices[BillingPeriod.yearly]?.freeTrialDays, 14);
      expect(prices[BillingPeriod.monthly]?.freeTrialDays, isNull);
    });

    test('a trial purchase buys the trial offer and acknowledges it', () async {
      final port = _FakePort();
      final result = await _service(
        port,
      ).buyPlus(withTrial: true);
      expect(port.bought, _yearlyTrial);
      expect(result.status, PurchaseStatus.purchased);
      expect(result.receipt, 'token-1');
      expect(result.since, DateTime(2026, 10, 23));
      expect(port.acknowledged, hasLength(1));
    });

    test('the base plan is bought without a trial', () async {
      final port = _FakePort();
      await _service(port).buyPlus(period: BillingPeriod.monthly);
      expect(port.bought, _monthly);
    });

    test('cancelled and failed purchases unlock nothing', () async {
      expect(
        (await _service(
          _FakePort(outcome: StorePurchaseState.cancelled),
        ).buyPlus()).status,
        PurchaseStatus.cancelled,
      );
      expect(
        (await _service(
          _FakePort(outcome: StorePurchaseState.error),
        ).buyPlus()).status,
        PurchaseStatus.failed,
      );
    });

    test('a purchase the server rejects is not acknowledged', () async {
      final port = _FakePort();
      final result = await _service(
        port,
        verify: (_) async => false,
      ).buyPlus();
      expect(result.isActive, isFalse);
      expect(port.acknowledged, isEmpty);
    });

    test('restore finds an owned subscription', () async {
      final owned = _FakePort(
        owned: [
          StorePurchase(
            productId: 'finora_premium',
            state: StorePurchaseState.restored,
            date: DateTime(2026, 3, 1),
            receipt: 'token-0',
          ),
        ],
      );
      final restored = await _service(owned).restore();
      expect(restored.status, PurchaseStatus.restored);
      expect(restored.since, DateTime(2026, 3, 1));
      expect(
        (await _service(_FakePort()).restore()).status,
        PurchaseStatus.nothingToRestore,
      );
    });
  });

  test('a subscription cancelled in Google Play ends Premium on start', () async {
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(
          session: UserSession.demo().copyWith(
            plan: FinoraPlan.plus,
            plusSince: DateTime(2026, 1, 1),
          ),
        ),
        purchaseServiceProvider.overrideWithValue(
          _Store(const PurchaseResult(PurchaseStatus.nothingToRestore)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(billingSyncProvider.future);
    expect(container.read(sessionProvider).isPlus, isFalse);
  });

  test('an offline check keeps Premium', () async {
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(
          session: UserSession.demo().copyWith(plan: FinoraPlan.plus),
        ),
        purchaseServiceProvider.overrideWithValue(
          _Store(const PurchaseResult(PurchaseStatus.failed)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(billingSyncProvider.future);
    expect(container.read(sessionProvider).isPlus, isTrue);
  });

  testWidgets('store builds show the store price', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(),
          purchaseServiceProvider.overrideWithValue(
            _Store(const PurchaseResult(PurchaseStatus.nothingToRestore)),
          ),
        ],
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const PlusScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHF 59.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
