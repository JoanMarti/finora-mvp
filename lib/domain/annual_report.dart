import 'package:finora/domain/models.dart';
import 'package:finora/domain/price_changes.dart';

/// A recurring bill and what it costs over a year.
class YearlyBill {
  const YearlyBill({required this.merchant, required this.yearly});
  final String merchant;
  final Money yearly;
}

/// "Your year in Finora": the last twelve completed months (Premium).
class AnnualReport {
  const AnnualReport({
    required this.months,
    required this.netWorthStart,
    required this.netWorthEnd,
    required this.topBills,
    required this.recurringYearly,
    required this.priceIncreasesYearly,
  });

  /// Months a report needs at least.
  static const minimumMonths = 3;

  /// Bills listed in the report.
  static const billCount = 5;

  /// Builds the report from the completed months before [now], at most
  /// twelve. Returns `null` with fewer than [minimumMonths] months.
  static AnnualReport? of({
    required List<CashFlowPoint> cashFlow,
    required List<BalanceHistoryPoint> netWorth,
    required List<RecurringPayment> recurring,
    required List<PriceChange> priceChanges,
    required DateTime now,
  }) {
    final currentMonth = DateTime(now.year, now.month);
    final completed = [
      for (final point in cashFlow)
        if (DateTime(point.month.year, point.month.month).isBefore(currentMonth))
          point,
    ]..sort((a, b) => a.month.compareTo(b.month));
    if (completed.length < minimumMonths) return null;
    final months = completed.length > 12
        ? completed.sublist(completed.length - 12)
        : completed;

    bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
    Money? closing(DateTime month) =>
        netWorth.where((point) => same(point.month, month)).firstOrNull?.balance;
    final first = months.first.month;
    final last = months.last.month;

    // One line per merchant, the most expensive first.
    final byMerchant = <String, Money>{};
    for (final bill in recurring) {
      final yearly = bill.amount.abs() * 12;
      final known = byMerchant[bill.merchant];
      if (known == null || yearly.cents > known.cents) {
        byMerchant[bill.merchant] = yearly;
      }
    }
    final bills = [
      for (final entry in byMerchant.entries)
        YearlyBill(merchant: entry.key, yearly: entry.value),
    ]..sort((a, b) => b.yearly.cents.compareTo(a.yearly.cents));

    return AnnualReport(
      months: List.unmodifiable(months),
      netWorthStart:
          closing(DateTime(first.year, first.month - 1)) ?? closing(first),
      netWorthEnd: closing(last),
      topBills: bills.take(billCount).toList(),
      recurringYearly: Money.sum(byMerchant.values),
      priceIncreasesYearly: Money.sum(
        priceChanges.map((change) => change.yearlyImpact),
      ),
    );
  }

  /// Completed months, oldest first.
  final List<CashFlowPoint> months;
  final Money? netWorthStart;
  final Money? netWorthEnd;
  final List<YearlyBill> topBills;
  final Money recurringYearly;
  final Money priceIncreasesYearly;

  DateTime get start => months.first.month;
  DateTime get end => months.last.month;

  Money get income => Money.sum(months.map((point) => point.income));
  Money get spending => Money.sum(months.map((point) => point.spending));
  Money get saved => income - spending;
  double get savingsRate => income.isZero ? 0 : saved.cents / income.cents;

  static Money savedIn(CashFlowPoint point) => point.income - point.spending;

  CashFlowPoint get bestMonth => months.reduce(
    (a, b) => savedIn(b).cents > savedIn(a).cents ? b : a,
  );

  CashFlowPoint get toughestMonth => months.reduce(
    (a, b) => savedIn(b).cents < savedIn(a).cents ? b : a,
  );

  Money? get netWorthChange {
    final start = netWorthStart;
    final end = netWorthEnd;
    if (start == null || end == null) return null;
    return end - start;
  }
}
