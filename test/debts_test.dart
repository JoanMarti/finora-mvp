import 'package:finora/app/theme.dart';
import 'package:finora/application/debts.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/debts.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/analysis/analysis_screen.dart';
import 'package:finora/features/debts/debts_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Widget _screen(Widget child) => ProviderScope(
  overrides: testOverrides(),
  child: MaterialApp(
    theme: buildFinoraTheme(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

Debt _debt(
  String id,
  int francs,
  double rate,
  int minimum, {
  DebtKind kind = DebtKind.loan,
}) => Debt(
  id: id,
  name: id,
  kind: kind,
  balance: Money(francs.toDouble()),
  yearlyRate: rate,
  minimumPayment: Money(minimum.toDouble()),
);

void main() {
  group('Debt planner', () {
    test('a single debt follows the annuity maths', () {
      // CHF 1,000 at 12 % with CHF 100 a month: about 10.6 payments.
      final plan = DebtPlanner.simulate(
        [_debt('loan', 1000, .12, 100)],
        Money(100),
        PayoffStrategy.avalanche,
      );
      expect(plan.feasible, isTrue);
      expect(plan.months, 11);
      expect(plan.totalInterest.amount, inInclusiveRange(50, 65));
      expect(plan.payoffMonths, {'loan': 11});
    });

    test('avalanche saves interest, snowball clears a debt sooner', () {
      final debts = [
        _debt('card', 3000, .12, 150, kind: DebtKind.creditCard),
        _debt('loan', 1000, .05, 50),
      ];
      final avalanche = DebtPlanner.simulate(
        debts,
        Money(600),
        PayoffStrategy.avalanche,
      );
      final snowball = DebtPlanner.simulate(
        debts,
        Money(600),
        PayoffStrategy.snowball,
      );
      expect(avalanche.payoffMonths.keys.first, 'card');
      expect(snowball.payoffMonths.keys.first, 'loan');
      expect(
        avalanche.totalInterest.cents,
        lessThan(snowball.totalInterest.cents),
      );
      expect(snowball.payoffMonths['loan']!, lessThan(avalanche.payoffMonths['loan']!));
    });

    test('the payment never drops below the minimums', () {
      final debts = [_debt('a', 2000, .1, 80), _debt('b', 500, .1, 40)];
      final plan = DebtPlanner.simulate(debts, Money(50), PayoffStrategy.snowball);
      expect(plan.monthlyPayment, Money(120));
    });

    test('a payment below the interest never finishes', () {
      final plan = DebtPlanner.simulate(
        [_debt('loan', 10000, .12, 50)],
        Money(50),
        PayoffStrategy.avalanche,
      );
      expect(plan.feasible, isFalse);
      expect(plan.months, DebtPlanner.maxMonths);
    });

    test('Swiss rate caps and card minimums', () {
      expect(_debt('x', 1000, .11, 50).aboveLegalRate, isTrue);
      expect(
        _debt('x', 1000, .11, 50, kind: DebtKind.creditCard).aboveLegalRate,
        isFalse,
      );
      expect(_debt('x', 1000, .2, 50, kind: DebtKind.leasing).aboveLegalRate,
          isFalse);
      expect(SwissCreditRules.cardMinimum(Money(1845.5)), Money(92.28));
      expect(SwissCreditRules.cardMinimum(Money(600)), Money(50));
      expect(SwissCreditRules.cardMinimum(Money(30)), Money(30));
    });

    test('debts and settings survive storage', () {
      final session = UserSession.demo().copyWith(
        debts: [_debt('loan', 1000, .07, 100)],
        debtPayment: Money(300),
        payoffStrategy: PayoffStrategy.snowball,
      );
      final restored = UserSession.decode(session.encode())!;
      expect(restored.debts!.single.yearlyRate, .07);
      expect(restored.debtPayment, Money(300));
      expect(restored.payoffStrategy, PayoffStrategy.snowball);
      expect(UserSession.decode(UserSession.demo().encode())!.debts, isNull);
    });

    test('the plan starts from the connected credit card', () async {
      final container = createTestContainer();
      final debts = await container.read(debtsProvider.future);
      expect(debts.single.kind, DebtKind.creditCard);
      expect(debts.single.balance, Money(1845.5));
      expect(debts.single.yearlyRate, SwissCreditRules.maxCardRate);
      // Minimum 92.28 + 10 %, rounded up to CHF 10.
      expect(await container.read(debtPaymentProvider.future), Money(110));

      container.read(sessionProvider.notifier).setDebts(const []);
      expect(await container.read(debtsProvider.future), isEmpty);
    });
  });

  group('Spending abroad', () {
    test('card payments in other currencies and their likely fees', () async {
      final container = createTestContainer();
      final spending = await container.read(foreignSpendingProvider.future);
      expect(spending.count, 3);
      expect(spending.currencies, {'EUR'});
      expect(spending.lastMonth, Money(573.8));
      expect(spending.yearlyEstimate, Money(6885.6));
      expect(spending.yearlyFees.amount, closeTo(120.5, .01));
      expect(spending.yearlySaving.amount, closeTo(103.28, .01));
    });

    test('older or incoming foreign payments are ignored', () {
      final spending = ForeignSpending.of([
        FinancialTransaction(
          id: 'old',
          accountId: 'c',
          merchant: 'Hotel',
          category: TransactionCategory.other,
          bookedAt: testNow.subtract(const Duration(days: 40)),
          amount: Money(-300),
          foreignCurrency: 'EUR',
        ),
        FinancialTransaction(
          id: 'refund',
          accountId: 'c',
          merchant: 'Refund',
          category: TransactionCategory.other,
          bookedAt: testNow,
          amount: Money(50),
          foreignCurrency: 'USD',
        ),
      ], testNow);
      expect(spending.isEmpty, isTrue);
    });
  });

  testWidgets('the debt plan shows when the user is debt-free', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const DebtsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Debt-free by'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // Only the sheet's fields: the screen has its own payment field.
    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Car leasing');
    await tester.enterText(fields.at(1), '12000');
    await tester.enterText(fields.at(2), '3.9');
    await tester.enterText(fields.at(3), '350');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Named in the payoff order on the plan card and in the list.
    expect(find.text('Car leasing'), findsWidgets);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(DebtsScreen)),
      ).read(sessionProvider).debts,
      hasLength(2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the analysis shows spending abroad', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const AnalysisScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('SPENDING ABROAD'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('in EUR in the last 30 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
