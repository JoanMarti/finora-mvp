import 'package:finora/domain/models.dart';

enum BudgetStatus { onTrack, nearLimit, over }

class BudgetLine {
  const BudgetLine({
    required this.category,
    required this.limit,
    required this.spent,
  });

  final TransactionCategory category;
  final Money limit;
  final Money spent;

  double get share => limit.isZero ? 1 : spent.cents / limit.cents;
  Money get remaining => limit - spent;

  /// From 80 % of the limit on, the budget is close to running out.
  BudgetStatus get status => share > 1
      ? BudgetStatus.over
      : share >= .8
      ? BudgetStatus.nearLimit
      : BudgetStatus.onTrack;
}

/// This month's budgets against spending in the everyday accounts.
class BudgetSummary {
  const BudgetSummary({
    required this.lines,
    required this.unbudgeted,
    required this.daysLeft,
  });

  factory BudgetSummary.of(
    Map<TransactionCategory, Money> limits,
    List<SpendingCategory> spending,
    DateTime now,
  ) {
    Money spentOn(TransactionCategory category) => Money.sum(
      spending
          .where((item) => item.category == category)
          .map((item) => item.amount.abs()),
    );
    final lines = [
      for (final category in TransactionCategory.values)
        if (limits[category] case final limit?)
          BudgetLine(category: category, limit: limit, spent: spentOn(category)),
    ]..sort((a, b) => b.share.compareTo(a.share));
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return BudgetSummary(
      lines: lines,
      unbudgeted: [
        for (final item in spending)
          if (!limits.containsKey(item.category) &&
              item.category != TransactionCategory.income)
            item,
      ],
      daysLeft: lastDay - now.day + 1,
    );
  }

  final List<BudgetLine> lines;

  /// Spending categories without a budget yet.
  final List<SpendingCategory> unbudgeted;

  /// Days left in the month, today included.
  final int daysLeft;

  bool get isEmpty => lines.isEmpty;
  Money get totalLimit => Money.sum(lines.map((line) => line.limit));
  Money get totalSpent => Money.sum(lines.map((line) => line.spent));
  Money get totalRemaining => totalLimit - totalSpent;

  /// What can still be spent per day without breaking the budgets.
  Money get safePerDay => totalRemaining.isNegative || daysLeft <= 0
      ? Money.zero
      : totalRemaining * (1 / daysLeft);

  List<BudgetLine> get overBudget => [
    for (final line in lines)
      if (line.status == BudgetStatus.over) line,
  ];

  /// A starting point: each category's spending rounded up to CHF 50.
  static Map<TransactionCategory, Money> suggest(
    List<SpendingCategory> spending,
  ) => {
    for (final item in spending)
      if (item.category != TransactionCategory.income && !item.amount.isZero)
        item.category: Money.cents(
          ((item.amount.abs().cents + 4999) ~/ 5000) * 5000,
        ),
  };
}

// -----------------------------------------------------------------------------
// Subscriptions
// -----------------------------------------------------------------------------

enum SubscriptionDecision { keep, toCancel, cancelled }

class SubscriptionItem {
  const SubscriptionItem({required this.payment, this.decision});

  final RecurringPayment payment;

  /// `null` until the user decides.
  final SubscriptionDecision? decision;

  Money get monthly => payment.amount.abs();
  Money get yearly => monthly * 12;
}

/// Optional recurring services the user can review and cancel. Mandatory
/// bills (radio/TV fee, insurance, electricity) are left out.
class SubscriptionPlan {
  const SubscriptionPlan(this.items);

  factory SubscriptionPlan.of(
    List<RecurringPayment> payments,
    Map<String, SubscriptionDecision> decisions,
  ) => SubscriptionPlan([
    for (final payment in payments)
      if (isOptional(payment.category))
        SubscriptionItem(
          payment: payment,
          decision: decisions[payment.merchant],
        ),
  ]..sort((a, b) => b.monthly.compareTo(a.monthly)));

  static bool isOptional(BillCategory category) =>
      category == BillCategory.streaming ||
      category == BillCategory.membership ||
      category == BillCategory.phoneInternet;

  final List<SubscriptionItem> items;

  Money _sum(bool Function(SubscriptionItem) test) =>
      Money.sum(items.where(test).map((item) => item.yearly));

  /// Yearly cost of everything not yet cancelled.
  Money get yearlyTotal =>
      _sum((item) => item.decision != SubscriptionDecision.cancelled);

  /// Yearly saving once the planned cancellations are done.
  Money get plannedSaving =>
      _sum((item) => item.decision == SubscriptionDecision.toCancel);

  /// Yearly saving from cancellations the user confirmed.
  Money get achievedSaving =>
      _sum((item) => item.decision == SubscriptionDecision.cancelled);

  int get undecided => items.where((item) => item.decision == null).length;
}
