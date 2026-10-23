import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/analysis/analysis_screen.dart';
import 'package:finora/features/offers/opportunities_screen.dart';
import 'package:finora/features/overview/dashboard_screen.dart';
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

final _consented = UserSession.demo().copyWith(offersConsent: true);

Future<List<Opportunity>> _detect(UserSession session) async {
  final container = createTestContainer(session: session);
  return container.read(opportunitiesProvider.future);
}

void main() {
  group('Opportunity engine', () {
    test('needs express consent before analysing data', () async {
      expect(await _detect(UserSession.demo()), isEmpty);
      expect(
        await _detect(UserSession.demo().copyWith(offersConsent: false)),
        isEmpty,
      );
    });

    test('finds deadline-driven opportunities first', () async {
      final found = await _detect(_consented);
      final kinds = found.map((item) => item.kind).toList();
      expect(kinds.first, OpportunityKind.healthInsuranceSwitch);
      expect(kinds[1], OpportunityKind.pillar3aRoom);
      expect(
        kinds,
        containsAll([
          OpportunityKind.insuranceReview,
          OpportunityKind.telecomPlan,
          OpportunityKind.subscriptionsReview,
          OpportunityKind.bankFees,
        ]),
      );
      // No mortgage is connected in the demo profile.
      expect(kinds, isNot(contains(OpportunityKind.mortgageRenewal)));
    });

    test('estimates the health insurance saving from the premium', () async {
      final health = (await _detect(_consented)).first;
      // CHF 348.20 a month → CHF 4,178 a year → 5–15 %, rounded to CHF 10.
      expect(health.savingLow, Money(210));
      expect(health.savingHigh, Money(630));
      expect(health.subject, 'CSS Insurance');
      expect(health.revenue, RevenueModel.leadFee);
      expect(health.deadline, DateTime(2026, 11, 30));
    });

    test('the health insurance switch is seasonal', () {
      final found = OpportunityEngine.detect(
        OpportunityInput(
          accounts: const [],
          analytics: {
            'a': AccountAnalytics(
              monthlyIncome: Money.zero,
              monthlySpending: Money.zero,
              balanceHistory: const [],
              cashFlowHistory: const [],
              recurringPayments: [
                RecurringPayment(
                  merchant: 'CSS Insurance',
                  category: BillCategory.healthInsurance,
                  amount: const Money.cents(-34820),
                  cadence: BillCadence.monthly,
                  nextDueAt: DateTime(2026, 3, 1),
                ),
              ],
              spendingCategories: const [],
            ),
          },
          pillar3aContributionsThisYear: Money.zero,
          now: DateTime(2026, 2, 10),
        ),
      );
      expect(
        found.map((item) => item.kind),
        isNot(contains(OpportunityKind.healthInsuranceSwitch)),
      );
    });

    test('suggests opening a Pillar 3a when there is none', () async {
      final found = await _detect(
        _consented.copyWith(
          products: {
            FinancialProductType.currentAccount,
            FinancialProductType.savings,
          },
        ),
      );
      expect(
        found.map((item) => item.kind),
        contains(OpportunityKind.pillar3aOpen),
      );
    });

    test('dismissed opportunities stay hidden until restored', () async {
      final container = createTestContainer(session: _consented);
      final controller = container.read(sessionProvider.notifier);
      controller.dismissOpportunity(OpportunityKind.telecomPlan.name);
      var found = await container.read(opportunitiesProvider.future);
      expect(
        found.map((item) => item.kind),
        isNot(contains(OpportunityKind.telecomPlan)),
      );
      controller.restoreOpportunities();
      found = await container.read(opportunitiesProvider.future);
      expect(
        found.map((item) => item.kind),
        contains(OpportunityKind.telecomPlan),
      );
    });

    test('consent and dismissals survive storage', () {
      final session = _consented.copyWith(dismissedOpportunities: {'cardFees'});
      final restored = UserSession.decode(session.encode())!;
      expect(restored.offersConsent, isTrue);
      expect(restored.dismissedOpportunities, {'cardFees'});
    });
  });

  group('Spending analysis', () {
    test('combines every everyday account', () async {
      final container = createTestContainer();
      final analysis = await container.read(spendingAnalysisProvider.future);
      expect(analysis.accountCount, 2);
      expect(analysis.combined.monthlySpending, Money(6426));
      expect(analysis.combined.monthlyIncome, Money(9350));
      expect(analysis.largestCategory?.category, TransactionCategory.groceries);
      expect(analysis.combined.cashFlowHistory.length, 6);
      expect(analysis.fixedCostShare, greaterThan(0));
    });
  });

  group('Offer tracking', () {
    test('opening and following an offer is counted without personal data', () async {
      final container = createTestContainer(session: _consented);
      final telecom = (await container.read(opportunitiesProvider.future))
          .firstWhere((item) => item.kind == OpportunityKind.telecomPlan);
      container.read(sessionProvider.notifier)
        ..recordOfferEvent(telecom, OfferEventType.viewed)
        ..recordOfferEvent(telecom, OfferEventType.partnerClicked);
      final funnel = container.read(funnelProvider);
      expect(funnel.count(OfferEventType.viewed), 1);
      expect(funnel.count(OfferEventType.partnerClicked), 1);
      expect(funnel.pursuedSavingHigh, telecom.savingHigh);
    });
  });

  testWidgets('dashboard asks for consent, then shows ways to save', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const DashboardScreen()));
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Yes, show me'),
      300,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, show me'));
    await tester.pumpAndSettle();
    expect(find.text('Yes, show me'), findsNothing);

    // The section changed height: start again from the top.
    await tester.drag(list, const Offset(0, 6000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Compare health insurance before 30 November'),
      200,
      scrollable: list,
    );
    expect(find.textContaining('Up to CHF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an offer explains itself and asks before sharing', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _screen(const OpportunitiesScreen(), session: _consented),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compare health insurance before 30 November'), findsOneWidget);
    await tester.tap(find.text('Compare health insurance before 30 November'));
    await tester.pumpAndSettle();

    expect(find.text('Why you see this'), findsOneWidget);
    expect(find.textContaining('CSS Insurance'), findsOneWidget);
    expect(find.textContaining('at most CHF 70'), findsOneWidget);

    final action = find.widgetWithText(FilledButton, 'Compare offers');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(action).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Demo'), findsOneWidget);
    final session = ProviderScope.containerOf(
      tester.element(find.byType(OpportunitiesScreen)),
    ).read(sessionProvider);
    expect(
      session.consentLog.last.purpose,
      ConsentPurpose.partnerSharing,
    );
    expect(session.consentLog.last.offerKind, OpportunityKind.healthInsuranceSwitch);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing an offer removes it from the list', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _screen(const OpportunitiesScreen(), session: _consented),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Compare health insurance before 30 November'));
    await tester.pumpAndSettle();
    final dismiss = find.text('Not interested');
    await tester.ensureVisible(dismiss);
    await tester.pumpAndSettle();
    await tester.tap(dismiss);
    await tester.pumpAndSettle();

    expect(
      find.text('Compare health insurance before 30 November'),
      findsNothing,
    );
  });

  testWidgets('analysis screen shows key figures across accounts', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const AnalysisScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Spending analysis'), findsOneWidget);
    expect(find.text('Savings rate'), findsOneWidget);
    expect(find.text('Groceries'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
