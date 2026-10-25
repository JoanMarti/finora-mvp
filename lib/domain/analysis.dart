import 'package:finora/domain/models.dart';

/// Spending picture across every everyday account, built by merging each
/// account's analytics. It reuses [AccountAnalytics] so the same charts work
/// for one account or for all of them.
class SpendingAnalysis {
  const SpendingAnalysis({required this.combined, required this.accountCount});

  /// Merges the analytics of everyday (current) accounts. Card spending is
  /// left out because it is paid from a current account and would be
  /// counted twice.
  factory SpendingAnalysis.combine(
    Map<FinancialAccount, AccountAnalytics> analyticsByAccount,
  ) {
    final everyday = analyticsByAccount.entries
        .where(
          (entry) => entry.key.type == FinancialProductType.currentAccount,
        )
        .map((entry) => entry.value)
        .toList();

    final cashFlowByMonth = <DateTime, (Money, Money)>{};
    final categories = <TransactionCategory, (Money, int)>{};
    for (final analytics in everyday) {
      for (final point in analytics.cashFlowHistory) {
        final (income, spending) =
            cashFlowByMonth[point.month] ?? (Money.zero, Money.zero);
        cashFlowByMonth[point.month] = (
          income + point.income,
          spending + point.spending,
        );
      }
      for (final category in analytics.spendingCategories) {
        final (amount, color) =
            categories[category.category] ?? (Money.zero, category.colorValue);
        categories[category.category] = (amount + category.amount, color);
      }
    }

    final months = cashFlowByMonth.keys.toList()..sort();
    final mergedCategories = [
      for (final entry in categories.entries)
        SpendingCategory(
          category: entry.key,
          amount: entry.value.$1,
          colorValue: entry.value.$2,
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    return SpendingAnalysis(
      accountCount: everyday.length,
      combined: AccountAnalytics(
        monthlyIncome: Money.sum(everyday.map((item) => item.monthlyIncome)),
        monthlySpending: Money.sum(
          everyday.map((item) => item.monthlySpending),
        ),
        balanceHistory: const [],
        cashFlowHistory: [
          for (final month in months)
            CashFlowPoint(
              month: month,
              income: cashFlowByMonth[month]!.$1,
              spending: cashFlowByMonth[month]!.$2,
            ),
        ],
        recurringPayments: [
          for (final analytics in analyticsByAccount.values)
            ...analytics.recurringPayments,
        ]..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt)),
        spendingCategories: mergedCategories,
      ),
    );
  }

  final AccountAnalytics combined;

  /// Number of everyday accounts included.
  final int accountCount;

  bool get isEmpty => accountCount == 0;

  Money get recurringYearly => combined.recurringTotal * 12;

  /// Share of monthly spending that is committed to recurring bills.
  double get fixedCostShare => combined.monthlySpending.isZero
      ? 0.0
      : (combined.recurringTotal.cents / combined.monthlySpending.cents)
            .clamp(0.0, 1.0)
            .toDouble();

  SpendingCategory? get largestCategory =>
      combined.spendingCategories.isEmpty
      ? null
      : combined.spendingCategories.first;
}
