import 'package:finora/domain/models.dart';

/// Time windows for the activity list.
enum ActivityPeriod { all, thisMonth, threeMonths, twelveMonths }

/// Money in, money out or both.
enum ActivityDirection { both, moneyIn, moneyOut }

/// Narrows the activity list; the text search stays in the screen because
/// it matches translated category names.
class TransactionFilter {
  const TransactionFilter({
    this.period = ActivityPeriod.all,
    this.direction = ActivityDirection.both,
    this.categories = const {},
    this.accountId,
  });

  final ActivityPeriod period;
  final ActivityDirection direction;

  /// Empty means every category.
  final Set<TransactionCategory> categories;

  /// `null` means every account.
  final String? accountId;

  /// How many filters differ from the default, for the filter button.
  int get activeCount =>
      (period == ActivityPeriod.all ? 0 : 1) +
      (direction == ActivityDirection.both ? 0 : 1) +
      (categories.isEmpty ? 0 : 1) +
      (accountId == null ? 0 : 1);

  bool get isEmpty => activeCount == 0;

  /// First day included, or `null` for everything.
  DateTime? since(DateTime now) => switch (period) {
    ActivityPeriod.all => null,
    ActivityPeriod.thisMonth => DateTime(now.year, now.month),
    ActivityPeriod.threeMonths => DateTime(now.year, now.month - 2),
    ActivityPeriod.twelveMonths => DateTime(now.year, now.month - 11),
  };

  bool matches(FinancialTransaction item, DateTime now) {
    final start = since(now);
    if (start != null && item.bookedAt.isBefore(start)) return false;
    if (direction == ActivityDirection.moneyIn && item.amount.isNegative) {
      return false;
    }
    if (direction == ActivityDirection.moneyOut && !item.amount.isNegative) {
      return false;
    }
    if (categories.isNotEmpty && !categories.contains(item.category)) {
      return false;
    }
    if (accountId != null && item.accountId != accountId) return false;
    return true;
  }

  TransactionFilter copyWith({
    ActivityPeriod? period,
    ActivityDirection? direction,
    Set<TransactionCategory>? categories,
    String? Function()? accountId,
  }) => TransactionFilter(
    period: period ?? this.period,
    direction: direction ?? this.direction,
    categories: categories ?? this.categories,
    accountId: accountId == null ? this.accountId : accountId(),
  );
}

/// Totals of a list of bookings.
class ActivityTotals {
  const ActivityTotals({required this.moneyIn, required this.moneyOut});

  factory ActivityTotals.of(Iterable<FinancialTransaction> items) =>
      ActivityTotals(
        moneyIn: Money.sum([
          for (final item in items)
            if (!item.amount.isNegative) item.amount,
        ]),
        moneyOut: Money.sum([
          for (final item in items)
            if (item.amount.isNegative) item.amount.abs(),
        ]),
      );

  final Money moneyIn;
  final Money moneyOut;
}
