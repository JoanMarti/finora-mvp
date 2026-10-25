import 'package:finora/domain/models.dart';

/// Things worth telling the user about a month, as facts; the UI words
/// them.
enum ReportHighlightKind {
  bestSavingsMonth,
  spendingAboveAverage,
  spendingBelowAverage,
  netWorthUp,
  netWorthDown,
  subscriptionsSaved,
}

class ReportHighlight {
  const ReportHighlight(this.kind, {this.amount, this.percent});
  final ReportHighlightKind kind;
  final Money? amount;
  final int? percent;
}

/// "Your month in Finora": one completed month against the one before and
/// the six-month average.
class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.income,
    required this.spending,
    required this.previousIncome,
    required this.previousSpending,
    required this.averageSpending,
    required this.netWorthEnd,
    required this.netWorthStart,
    required this.highlights,
  });

  /// Builds the report for [month] (first day of the month). Returns
  /// `null` when the cash flow of that month is unknown.
  static MonthlyReport? of({
    required DateTime month,
    required List<CashFlowPoint> cashFlow,
    required List<BalanceHistoryPoint> netWorth,
    Money subscriptionsSaved = Money.zero,
  }) {
    bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
    final index = cashFlow.indexWhere((point) => same(point.month, month));
    if (index < 0) return null;
    final current = cashFlow[index];
    final previous = index > 0 ? cashFlow[index - 1] : null;
    final window = cashFlow.sublist(0, index + 1);
    final averageSpending =
        Money.sum(window.map((point) => point.spending)) *
        (1 / window.length);

    Money? closing(DateTime value) =>
        netWorth.where((point) => same(point.month, value)).firstOrNull?.balance;
    final end = closing(month);
    final start = closing(DateTime(month.year, month.month - 1));

    final saved = current.income - current.spending;
    final highlights = <ReportHighlight>[
      if (window.length >= 3 &&
          window.every(
            (point) =>
                (point.income - point.spending).cents <= saved.cents,
          ))
        ReportHighlight(ReportHighlightKind.bestSavingsMonth, amount: saved),
    ];
    if (window.length >= 3 && !averageSpending.isZero) {
      final difference = current.spending - averageSpending;
      final percent = (difference.cents * 100 / averageSpending.cents).round();
      if (percent >= 5) {
        highlights.add(
          ReportHighlight(
            ReportHighlightKind.spendingAboveAverage,
            amount: difference,
            percent: percent,
          ),
        );
      } else if (percent <= -5) {
        highlights.add(
          ReportHighlight(
            ReportHighlightKind.spendingBelowAverage,
            amount: difference.abs(),
            percent: -percent,
          ),
        );
      }
    }
    if (end != null && start != null && end != start) {
      final change = end - start;
      highlights.add(
        ReportHighlight(
          change.isNegative
              ? ReportHighlightKind.netWorthDown
              : ReportHighlightKind.netWorthUp,
          amount: change.abs(),
        ),
      );
    }
    if (!subscriptionsSaved.isZero) {
      highlights.add(
        ReportHighlight(
          ReportHighlightKind.subscriptionsSaved,
          amount: subscriptionsSaved,
        ),
      );
    }
    return MonthlyReport(
      month: month,
      income: current.income,
      spending: current.spending,
      previousIncome: previous?.income,
      previousSpending: previous?.spending,
      averageSpending: averageSpending,
      netWorthEnd: end,
      netWorthStart: start,
      highlights: highlights,
    );
  }

  /// The months a report can be shown for: completed months with cash
  /// flow, most recent first.
  static List<DateTime> availableMonths(
    List<CashFlowPoint> cashFlow,
    DateTime now,
  ) => [
    for (final point in cashFlow.reversed)
      if (point.month.year < now.year ||
          (point.month.year == now.year && point.month.month < now.month))
        DateTime(point.month.year, point.month.month),
  ];

  final DateTime month;
  final Money income;
  final Money spending;
  final Money? previousIncome;
  final Money? previousSpending;
  final Money averageSpending;
  final Money? netWorthEnd;
  final Money? netWorthStart;
  final List<ReportHighlight> highlights;

  Money get saved => income - spending;
  double get savingsRate => income.isZero ? 0 : saved.cents / income.cents;

  double? get previousSavingsRate {
    final income = previousIncome;
    final spending = previousSpending;
    if (income == null || spending == null || income.isZero) return null;
    return (income - spending).cents / income.cents;
  }

  /// Change in spending against the month before, e.g. 0.08 for +8 %.
  double? get spendingChange {
    final before = previousSpending;
    if (before == null || before.isZero) return null;
    return (spending.cents - before.cents) / before.cents;
  }

  Money? get netWorthChange {
    final end = netWorthEnd;
    final start = netWorthStart;
    return end == null || start == null ? null : end - start;
  }
}
