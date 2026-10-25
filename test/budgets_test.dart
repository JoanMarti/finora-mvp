import 'package:finora/app/theme.dart';
import 'package:finora/application/budgets.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/budgets.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/budgets/budgets_screen.dart';
import 'package:finora/features/budgets/subscriptions_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
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

const _spending = [
  SpendingCategory(
    category: TransactionCategory.groceries,
    amount: Money.cents(74000),
    colorValue: 0,
  ),
  SpendingCategory(
    category: TransactionCategory.dining,
    amount: Money.cents(21020),
    colorValue: 0,
  ),
  SpendingCategory(
    category: TransactionCategory.income,
    amount: Money.cents(935000),
    colorValue: 0,
  ),
];

RecurringPayment _bill(String merchant, BillCategory category, int cents) =>
    RecurringPayment(
      merchant: merchant,
      category: category,
      amount: Money.cents(-cents),
      cadence: BillCadence.monthly,
      nextDueAt: DateTime(2026, 11, 1),
    );

void main() {
  group('Budgets', () {
    test('track spending against limits for the rest of the month', () {
      final summary = BudgetSummary.of(
        {
          TransactionCategory.groceries: Money(600),
          TransactionCategory.dining: Money(250),
        },
        _spending,
        testNow, // 23 October
      );
      expect(summary.daysLeft, 9);
      expect(summary.lines.first.category, TransactionCategory.groceries);
      expect(summary.lines.first.status, BudgetStatus.over);
      expect(summary.lines.first.remaining, Money(-140));
      expect(summary.lines.last.status, BudgetStatus.nearLimit);
      expect(summary.totalLimit, Money(850));
      expect(summary.totalSpent, Money(950.2));
      expect(summary.safePerDay, Money.zero);
      expect(summary.overBudget.single.category, TransactionCategory.groceries);
      expect(summary.unbudgeted, isEmpty);
    });

    test('suggestions round spending up to CHF 50 and skip income', () {
      final suggested = BudgetSummary.suggest(_spending);
      expect(suggested, {
        TransactionCategory.groceries: Money(750),
        TransactionCategory.dining: Money(250),
      });
    });

    test('safe daily amount spreads what is left', () {
      final summary = BudgetSummary.of(
        {TransactionCategory.groceries: Money(1000)},
        _spending,
        testNow,
      );
      expect(summary.safePerDay.amount, closeTo(260 / 9, .01));
      expect(
        summary.unbudgeted.map((item) => item.category),
        [TransactionCategory.dining],
      );
    });

    test('an exceeded budget raises an alert', () async {
      final container = createTestContainer(
        session: UserSession.demo().copyWith(
          budgets: {TransactionCategory.groceries: Money(100)},
        ),
      );
      final alerts = await container.read(alertsProvider.future);
      final budget = alerts.firstWhere(
        (alert) => alert.kind == AlertKind.budgetExceeded,
      );
      expect(budget.route, '/budgets');
      expect(budget.severity, AlertSeverity.warning);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.alertTitle(budget), 'Groceries budget exceeded');
    });
  });

  group('Subscriptions', () {
    test('only optional services, with planned and achieved savings', () {
      final plan = SubscriptionPlan.of(
        [
          _bill('Netflix', BillCategory.streaming, 2490),
          _bill('Swisscom', BillCategory.phoneInternet, 8990),
          _bill('Serafe', BillCategory.radioTvFee, 2790),
          _bill('CSS Insurance', BillCategory.healthInsurance, 34820),
        ],
        {
          'Netflix': SubscriptionDecision.toCancel,
          'Swisscom': SubscriptionDecision.keep,
        },
      );
      expect(plan.items.map((item) => item.payment.merchant), [
        'Swisscom',
        'Netflix',
      ]);
      expect(plan.plannedSaving, Money(298.8));
      expect(plan.achievedSaving, Money.zero);
      expect(plan.yearlyTotal, Money(1377.6));
      expect(plan.undecided, 0);
    });

    test('decisions survive storage', () {
      final session = UserSession.demo().copyWith(
        budgets: {TransactionCategory.dining: Money(250)},
        subscriptionDecisions: {'Netflix': SubscriptionDecision.cancelled},
      );
      final restored = UserSession.decode(session.encode())!;
      expect(restored.budgets, {TransactionCategory.dining: Money(250)});
      expect(restored.subscriptionDecisions, {
        'Netflix': SubscriptionDecision.cancelled,
      });
    });

    test('the demo profile lists its subscriptions', () async {
      final container = createTestContainer();
      final plan = await container.read(subscriptionPlanProvider.future);
      expect(
        plan.items.map((item) => item.payment.merchant),
        containsAll(['Swisscom', 'PureGym', 'Netflix']),
      );
      expect(
        plan.items.map((item) => item.payment.merchant),
        isNot(contains('Serafe')),
      );
    });
  });

  testWidgets('budgets can be suggested from spending', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const BudgetsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggest budgets from my spending'));
    await tester.pumpAndSettle();

    expect(find.text('THIS MONTH'), findsOneWidget);
    expect(_session(tester, BudgetsScreen).budgets, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a subscription can be planned and confirmed as cancelled', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const SubscriptionsScreen()));
    await tester.pumpAndSettle();

    final cancel = find.text('Cancel').first;
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.textContaining('Finora is read-only'), findsOneWidget);

    final done = find.text('Done, it is cancelled');
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(find.textContaining('Cancelled:'), findsOneWidget);
    expect(
      _session(tester, SubscriptionsScreen).subscriptionDecisions['Swisscom'],
      SubscriptionDecision.cancelled,
    );
    expect(tester.takeException(), isNull);
  });
}
