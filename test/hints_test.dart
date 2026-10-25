import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/accounts/account_detail_screen.dart';
import 'package:finora/features/analysis/analysis_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _consented = UserSession.demo().copyWith(offersConsent: true);

Widget _screen(Widget child, {UserSession? session}) => ProviderScope(
  overrides: testOverrides(session: session ?? _consented),
  child: MaterialApp(
    theme: buildFinoraTheme(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

RecurringPayment _bill(String merchant, BillCategory category) =>
    RecurringPayment(
      merchant: merchant,
      category: category,
      amount: const Money.cents(-5000),
      cadence: BillCadence.monthly,
      nextDueAt: DateTime(2026, 11, 1),
    );

void main() {
  group('New price rules', () {
    test('savings accounts get a rate suggestion each', () async {
      final found = await createTestContainer(
        session: _consented,
      ).read(opportunitiesProvider.future);
      final savings = found
          .where((item) => item.kind == OpportunityKind.savingsRate)
          .toList();
      expect(savings.map((item) => item.accountId), {
        'ubs-savings',
        'zkb-savings',
      });
      // CHF 20,000 × (0.75 % − 0.25 %) = CHF 100 a year at most.
      final ubs = savings.firstWhere((item) => item.accountId == 'ubs-savings');
      expect(ubs.savingHigh, Money(100));
      expect(ubs.savingLow, Money(50));
      expect(ubs.id, 'savingsRate:ubs-savings');
    });

    test('3a fees only for providers that are not already low-cost', () async {
      final found = await createTestContainer(
        session: _consented,
      ).read(opportunitiesProvider.future);
      final fees = found
          .where((item) => item.kind == OpportunityKind.pillar3aFees)
          .toList();
      expect(fees.single.accountId, 'ubs-3a');
      // CHF 15,200 × 0.75 % ≈ CHF 110 a year.
      expect(fees.single.savingHigh, Money(110));
    });

    test('household insurance is compared on its own', () async {
      final found = await createTestContainer(
        session: _consented,
      ).read(opportunitiesProvider.future);
      final household = found.firstWhere(
        (item) => item.kind == OpportunityKind.householdInsurance,
      );
      expect(household.subject, 'AXA');
      expect(household.savingHigh, Money(220));
    });

    test('dismissing one account keeps the other', () async {
      final container = createTestContainer(
        session: _consented.copyWith(
          dismissedOpportunities: {'savingsRate:ubs-savings'},
        ),
      );
      final found = await container.read(opportunitiesProvider.future);
      expect(
        found
            .where((item) => item.kind == OpportunityKind.savingsRate)
            .map((item) => item.accountId),
        ['zkb-savings'],
      );
      expect(
        container.read(accountOpportunitiesProvider('ubs-savings')),
        isEmpty,
      );
    });

    test('the funnel counts per kind', () {
      const a = Opportunity(
        kind: OpportunityKind.savingsRate,
        category: OpportunityCategory.banking,
        revenue: RevenueModel.affiliate,
        priority: 1,
        accountId: 'a',
      );
      const b = Opportunity(
        kind: OpportunityKind.savingsRate,
        category: OpportunityCategory.banking,
        revenue: RevenueModel.affiliate,
        priority: 1,
        accountId: 'b',
      );
      final stats = const FunnelStats()
          .record(a, OfferEventType.viewed)
          .record(b, OfferEventType.viewed);
      expect(stats.count(OfferEventType.viewed, kind: OpportunityKind.savingsRate), 2);
      expect(stats.kinds, [OpportunityKind.savingsRate]);
    });
  });

  group('Hints next to bills', () {
    const health = Opportunity(
      kind: OpportunityKind.healthInsuranceSwitch,
      category: OpportunityCategory.insurance,
      revenue: RevenueModel.leadFee,
      priority: 1,
      subject: 'CSS Insurance',
    );
    const subscriptions = Opportunity(
      kind: OpportunityKind.subscriptionsReview,
      category: OpportunityCategory.budget,
      revenue: RevenueModel.none,
      priority: 1,
    );

    test('match the bill they are about', () {
      final items = [health, subscriptions];
      expect(
        hintForBill(items, _bill('CSS Insurance', BillCategory.healthInsurance)),
        health,
      );
      expect(
        hintForBill(items, _bill('Other Kasse', BillCategory.healthInsurance)),
        isNull,
      );
      expect(
        hintForBill(items, _bill('Netflix', BillCategory.streaming)),
        subscriptions,
      );
      expect(hintForBill(items, _bill('Serafe', BillCategory.radioTvFee)), isNull);
    });
  });

  testWidgets('a savings account shows its rate suggestion', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _screen(const AccountDetailScreen(accountId: 'ubs-savings')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('100 a year'), findsOneWidget);

    await tester.tap(find.textContaining('100 a year'));
    await tester.pumpAndSettle();
    expect(find.text('Why you see this'), findsOneWidget);
    expect(find.textContaining('up to 1%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without consent no suggestion appears', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _screen(
        const AccountDetailScreen(accountId: 'ubs-savings'),
        session: UserSession.demo(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Save up to'), findsNothing);
  });

  testWidgets('bills in the analysis carry their suggestion', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const AnalysisScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('630 a year'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('630 a year'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
