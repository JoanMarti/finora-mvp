import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/offers/pilot_metrics_screen.dart';
import 'package:finora/features/planning/retirement_screen.dart';
import 'package:finora/features/planning/tax_summary_screen.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/features/privacy/privacy_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Widget _screen(Widget child, {UserSession? session}) => ProviderScope(
  overrides: testOverrides(session: session),
  child: MaterialApp(
    theme: buildFinoraTheme(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

UserSession _session(WidgetTester tester, Type screen) =>
    ProviderScope.containerOf(
      tester.element(find.byType(screen)),
    ).read(sessionProvider);

const _telecom = Opportunity(
  kind: OpportunityKind.telecomPlan,
  category: OpportunityCategory.telecom,
  revenue: RevenueModel.leadFee,
  priority: 2,
  savingLow: Money.cents(20000),
  savingHigh: Money.cents(40000),
);

final _plus = UserSession.demo().copyWith(plan: FinoraPlan.plus);

void main() {
  group('Consent register', () {
    test('logs each offers answer once, with time and text version', () {
      final container = createTestContainer();
      final controller = container.read(sessionProvider.notifier);
      controller
        ..setOffersConsent(true)
        ..setOffersConsent(true);
      final log = container.read(sessionProvider).consentLog;
      expect(log, hasLength(1));
      expect(log.single.purpose, ConsentPurpose.offersAnalysis);
      expect(log.single.granted, isTrue);
      expect(log.single.at, testNow);
      expect(log.single.textVersion, ConsentRecord.currentTextVersion);
    });

    test('withdrawing clears offer data and logs every withdrawal', () {
      final container = createTestContainer();
      final controller = container.read(sessionProvider.notifier);
      controller
        ..setOffersConsent(true)
        ..recordPartnerConsent(OpportunityKind.telecomPlan)
        ..recordOfferEvent(_telecom, OfferEventType.viewed)
        ..dismissOpportunity('cardFees')
        ..withdrawOfferConsents();

      final session = container.read(sessionProvider);
      expect(session.offersConsent, isFalse);
      expect(session.funnel.isEmpty, isTrue);
      expect(session.dismissedOpportunities, isEmpty);
      final withdrawals = session.consentLog.where((r) => !r.granted).toList();
      expect(withdrawals.map((r) => r.purpose), [
        ConsentPurpose.offersAnalysis,
        ConsentPurpose.partnerSharing,
      ]);
      expect(withdrawals.last.offerKind, OpportunityKind.telecomPlan);

      // A second withdrawal has nothing left to withdraw.
      controller.withdrawOfferConsents();
      expect(container.read(sessionProvider).consentLog, hasLength(4));
    });
  });

  group('Funnel', () {
    test('counts events and the saving the user pursued', () {
      final funnel = const FunnelStats()
          .record(_telecom, OfferEventType.viewed)
          .record(_telecom, OfferEventType.viewed)
          .record(_telecom, OfferEventType.partnerClicked);
      expect(funnel.count(OfferEventType.viewed), 2);
      expect(
        funnel.count(OfferEventType.partnerClicked, kind: _telecom.kind),
        1,
      );
      expect(funnel.clickRate, .5);
      expect(funnel.pursuedSavingHigh, Money(400));
      expect(funnel.kinds, [OpportunityKind.telecomPlan]);
    });

    test('plan, consents and funnel survive storage', () {
      final session = _plus.copyWith(
        plusSince: testNow,
        consentLog: [
          ConsentRecord(
            purpose: ConsentPurpose.partnerSharing,
            granted: true,
            at: testNow,
            subject: 'telecomPlan',
          ),
        ],
        funnel: const FunnelStats().record(
          _telecom,
          OfferEventType.partnerClicked,
        ),
      );
      final restored = UserSession.decode(session.encode())!;
      expect(restored.isPlus, isTrue);
      expect(restored.plusSince, testNow);
      expect(restored.consentLog.single.offerKind, OpportunityKind.telecomPlan);
      expect(restored.funnel.count(OfferEventType.partnerClicked), 1);
      expect(restored.funnel.pursuedSavingLow, Money(200));
    });

    test('older sessions load on the free plan', () {
      final restored = UserSession.decode('{"email":"a@b.ch"}')!;
      expect(restored.plan, FinoraPlan.free);
      expect(restored.consentLog, isEmpty);
      expect(restored.funnel.isEmpty, isTrue);
    });
  });

  group('Retirement scenarios', () {
    test('cautious < base < favourable, and base is the main projection', () async {
      final container = createTestContainer();
      final scenarios = await container.read(
        retirementScenariosProvider.future,
      );
      final base = await container.read(retirementProjectionProvider.future);
      final cautious = scenarios[RetirementScenario.cautious]!.totalMonthly;
      final favourable = scenarios[RetirementScenario.favourable]!.totalMonthly;
      expect(cautious.cents, lessThan(base.totalMonthly.cents));
      expect(favourable.cents, greaterThan(base.totalMonthly.cents));
      expect(scenarios[RetirementScenario.base]!.totalMonthly, base.totalMonthly);
      // AHV does not depend on the scenario.
      expect(
        scenarios[RetirementScenario.cautious]!.ahvMonthly,
        base.ahvMonthly,
      );
    });
  });

  testWidgets('Plus can be started and unlocks scenarios', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const PlusScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Retirement scenarios'), findsWidgets);
    final start = find.textContaining('Subscribe ·');
    // The button sits below the fold of a lazily built list.
    await tester.scrollUntilVisible(
      start,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('Start Finora Premium?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start Premium'));
    await tester.pumpAndSettle();

    expect(_session(tester, PlusScreen).isPlus, isTrue);
    // The status card sits at the top of the plans screen.
    await tester.scrollUntilVisible(
      find.text('Finora Premium is active'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Finora Premium is active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retirement scenarios are locked on the free plan', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const RetirementScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Compare retirement scenarios'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Unlock with Premium'), findsOneWidget);
    expect(find.text('Cautious'), findsNothing);
  });

  testWidgets('Plus members compare three scenarios', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const RetirementScreen(), session: _plus));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Favourable'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cautious'), findsOneWidget);
    expect(find.text('Your assumptions'), findsOneWidget);
    expect(find.textContaining('of target'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tax export is marked as a Plus feature', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const TaxSummaryScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Copy as CSV · Premium'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Copy as CSV · Premium'), findsOneWidget);
  });

  testWidgets('privacy screen shows the history and withdraws consent', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final session = UserSession.demo().copyWith(
      offersConsent: true,
      consentLog: [
        ConsentRecord(
          purpose: ConsentPurpose.offersAnalysis,
          granted: true,
          at: testNow,
        ),
        ConsentRecord(
          purpose: ConsentPurpose.partnerSharing,
          granted: true,
          at: testNow,
          subject: 'telecomPlan',
        ),
      ],
    );
    await tester.pumpWidget(_screen(const PrivacyScreen(), session: session));
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.textContaining('Share data with the partner'),
      300,
      scrollable: list,
    );
    expect(
      find.text('Share data with the partner: Pay less for phone & internet'),
      findsOneWidget,
    );

    final withdraw = find.text('Withdraw all offer consents');
    await tester.scrollUntilVisible(withdraw, 300, scrollable: list);
    await tester.pumpAndSettle();
    await tester.tap(withdraw);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
    await tester.pumpAndSettle();

    final after = _session(tester, PrivacyScreen);
    expect(after.offersConsent, isFalse);
    expect(after.consentLog.where((r) => !r.granted), hasLength(2));
    expect(find.text('Your offer consents were withdrawn.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pilot metrics summarise the funnel', (tester) async {
    usePhoneViewport(tester);
    final session = UserSession.demo().copyWith(
      offersConsent: true,
      funnel: const FunnelStats()
          .record(_telecom, OfferEventType.viewed)
          .record(_telecom, OfferEventType.viewed)
          .record(_telecom, OfferEventType.partnerClicked),
    );
    await tester.pumpWidget(
      _screen(const PilotMetricsScreen(), session: session),
    );
    await tester.pumpAndSettle();

    expect(find.text('Given'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pay less for phone & internet'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pay less for phone & internet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
