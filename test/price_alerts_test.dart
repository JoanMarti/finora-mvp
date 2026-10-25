import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/price_changes.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/price_alerts/price_alerts_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime(2026, 10, 23);

FinancialTransaction _charge(
  String merchant,
  int daysAgo,
  int cents, {
  TransactionCategory category = TransactionCategory.utilities,
}) => FinancialTransaction(
  id: '$merchant-$daysAgo',
  accountId: 'a',
  merchant: merchant,
  category: category,
  bookedAt: _now.subtract(Duration(days: daysAgo)),
  amount: Money.cents(-cents),
);

final _premium = UserSession.demo().copyWith(plan: FinoraPlan.plus);

Widget _app(Widget child, UserSession session) => ProviderScope(
  overrides: testOverrides(session: session),
  child: MaterialApp(
    theme: buildFinoraTheme(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

void main() {
  group('Price changes', () {
    test('a monthly charge that went up is found', () {
      final changes = PriceChangeDetector.detect([
        _charge('Swisscom', 9, 8990),
        _charge('Swisscom', 39, 8490),
      ], now: _now);
      final change = changes.single;
      expect(change.previous, const Money.cents(8490));
      expect(change.current, const Money.cents(8990));
      expect(change.rate, closeTo(.0589, .001));
      expect(change.yearlyImpact, const Money.cents(6000));
    });

    test('variable spending, small steps and odd gaps are ignored', () {
      expect(
        PriceChangeDetector.detect([
          _charge('Migros', 2, 9000, category: TransactionCategory.groceries),
          _charge('Migros', 32, 6000, category: TransactionCategory.groceries),
          _charge('EWZ', 5, 6450),
          _charge('EWZ', 35, 6400),
          _charge('Serafe', 5, 3000),
          _charge('Serafe', 100, 2000),
        ], now: _now),
        isEmpty,
      );
    });

    test('streaming booked as shopping still counts', () {
      final changes = PriceChangeDetector.detect([
        _charge('Spotify', 7, 1295, category: TransactionCategory.shopping),
        _charge('Spotify', 37, 1195, category: TransactionCategory.shopping),
      ], now: _now);
      expect(changes.single.merchant, 'Spotify');
    });

    test('the demo finds Swisscom first, then Spotify', () async {
      final changes = await createTestContainer().read(
        priceChangesProvider.future,
      );
      expect(changes.map((change) => change.merchant), [
        'Swisscom',
        'Spotify',
      ]);
    });

    test('alerts include increases only with Premium', () async {
      final free = await createTestContainer().read(alertsProvider.future);
      expect(
        free.map((alert) => alert.kind),
        isNot(contains(AlertKind.priceIncrease)),
      );
      final premium = await createTestContainer(
        session: _premium,
      ).read(alertsProvider.future);
      final alert = premium.firstWhere(
        (alert) => alert.kind == AlertKind.priceIncrease,
      );
      expect(alert.subject, 'Swisscom');
      expect(alert.previousAmount, const Money.cents(8490));
    });
  });

  testWidgets('free users see how many increases there are', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _app(const Scaffold(body: PriceAlertsCard()), UserSession.demo()),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 price increases found in your bills'), findsOneWidget);
    expect(find.text('Swisscom'), findsNothing);
  });

  testWidgets('Premium lists increases and links to the matching offer', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _app(
        const PriceAlertsScreen(),
        _premium.copyWith(offersConsent: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Swisscom'), findsOneWidget);
    expect(find.textContaining('+6%'), findsOneWidget);
    await tester.tap(find.text('Compare alternatives').first);
    await tester.pumpAndSettle();
    expect(find.text('Why you see this'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
