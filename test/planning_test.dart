import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/planning/goals_screen.dart';
import 'package:finora/features/planning/retirement_screen.dart';
import 'package:finora/features/planning/tax_summary_screen.dart';
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

void main() {
  group('AHV pension formula', () {
    const rules = SwissPensionRules.y2026;

    test('matches the official minimum, maximum and kink', () {
      expect(rules.ahvMonthlyPension(Money(15120)), Money(1260));
      expect(rules.ahvMonthlyPension(Money(45360)), Money(1915.20));
      expect(rules.ahvMonthlyPension(Money(90720)), Money(2520));
    });

    test('is capped at both ends', () {
      expect(rules.ahvMonthlyPension(Money(5000)), Money(1260));
      expect(rules.ahvMonthlyPension(Money(250000)), Money(2520));
    });
  });

  group('RetirementProjection', () {
    test('adds the 13th AHV pension and projects every pillar', () {
      final projection = RetirementProjection.of(
        RetirementProfile.demo,
        pillar3aBalance: const Money.cents(4456000),
        now: testNow,
      );
      expect(projection.retirementYear, 2053);
      expect(projection.yearsToRetirement, 27);
      expect(projection.ahvMonthly, Money(2730));
      expect(
        projection.pensionFundCapital.compareTo(
          RetirementProfile.demo.pensionFundBalance,
        ),
        greaterThan(0),
      );
      expect(projection.totalMonthly.compareTo(Money.zero), greaterThan(0));
      expect(projection.onTrack, isTrue);
    });

    test('shows a gap when savings are small', () {
      final projection = RetirementProjection.of(
        RetirementProfile.demo.copyWith(
          pensionFundBalance: Money.zero,
          annualPensionFundCredits: Money.zero,
          annualPillar3aContribution: Money.zero,
        ),
        pillar3aBalance: Money.zero,
        now: testNow,
      );
      expect(projection.onTrack, isFalse);
      expect(projection.gapMonthly.compareTo(Money.zero), greaterThan(0));
    });
  });

  group('GoalProgress', () {
    test('spreads the remaining amount over the months left', () {
      final goal = SavingsGoal(
        id: 'g',
        name: 'Flat deposit',
        target: Money(40000),
        deadline: DateTime(2028, 6),
        accountIds: const {'a'},
      );
      const account = FinancialAccount(
        id: 'a',
        institutionId: 'ubs',
        name: 'Savings',
        type: FinancialProductType.savings,
        balance: Money.cents(2850000),
        maskedIdentifier: '',
        monthlyChange: Money.zero,
      );
      final progress = GoalProgress.of(goal, const [account], testNow);
      expect(progress.saved, Money(28500));
      expect(progress.monthsLeft, 20);
      expect(progress.monthlyNeeded, Money(575));
      expect(progress.isReached, isFalse);
    });
  });

  group('Planning data in the session', () {
    test('goals, targets and the pension profile survive storage', () {
      final session = UserSession.demo().copyWith(
        targets: const WealthTargets(safetyBufferMonths: 9),
        retirement: RetirementProfile.demo.copyWith(birthYear: 1990),
      );
      final restored = UserSession.decode(session.encode())!;
      expect(restored.targets.safetyBufferMonths, 9);
      expect(restored.goals.single.name, 'Flat deposit');
      expect(restored.goals.single.accountIds, {'ubs-savings', 'zkb-savings'});
      expect(restored.retirement?.birthYear, 1990);
    });

    test('saving and deleting goals updates the session', () {
      final container = createTestContainer();
      final controller = container.read(sessionProvider.notifier);
      controller.saveGoal(
        SavingsGoal(id: 'car', name: 'Car', target: Money(15000)),
      );
      expect(container.read(sessionProvider).goals.length, 2);
      controller.deleteGoal('car');
      expect(container.read(sessionProvider).goals.length, 1);
    });
  });

  group('Tax summary', () {
    test('a past year is complete and caps the Pillar 3a deduction', () async {
      final container = createTestContainer();
      final summary = await container.read(taxSummaryProvider(2025).future);
      expect(summary.data.isComplete, isTrue);
      expect(summary.data.asOf, DateTime(2025, 12, 31));
      expect(summary.pillar3aDeductible, const Money.cents(725800));
      final savings = summary.bankAccounts.singleWhere(
        (item) => item.account.id == 'ubs-savings',
      );
      // CHF 20,000 today, CHF 300 a month added since the end of 2025.
      expect(savings.closingBalance, Money(17000));
      expect(savings.income, Money(85));
      expect(summary.debts.map((item) => item.account.id), contains('ubs-card'));
      expect(
        summary.netWealth,
        summary.bankTotal + summary.securitiesTotal - summary.debtTotal,
      );
    });

    test('the running year is marked as year to date', () async {
      final container = createTestContainer();
      final summary = await container.read(taxSummaryProvider(2026).future);
      expect(summary.data.isComplete, isFalse);
      expect(summary.data.asOf, testNow);
    });
  });

  testWidgets('goals screen shows progress and adds a goal', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const GoalsScreen()));
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Flat deposit'), 200, scrollable: list);
    expect(find.text('Flat deposit'), findsOneWidget);
    final monthly = find.textContaining('575.00 a month');
    await tester.scrollUntilVisible(monthly, 100, scrollable: list);
    expect(monthly, findsOneWidget);

    await tester.ensureVisible(find.text('Add a goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a goal'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Car');
    await tester.enterText(
      find.widgetWithText(TextField, 'Target amount'),
      '15000',
    );
    await tester.pump();
    final save = find.text('Save goal');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Car'), 200, scrollable: list);
    expect(find.text('Car'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retirement screen explains the example projection', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const RetirementScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Estimated retirement income from 2053'), findsOneWidget);
    expect(find.text('Use my figures'), findsOneWidget);
    expect(find.textContaining('On track'), findsOneWidget);
    expect(find.text('1st pillar · AHV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tax summary switches between years', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const TaxSummaryScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Balances on'), findsOneWidget);
    expect(find.text('BANK ACCOUNTS'), findsOneWidget);

    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Year to date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
