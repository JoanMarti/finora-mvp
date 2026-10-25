import 'package:finora/domain/models.dart';

/// A recurring charge that costs more than the time before.
class PriceChange {
  const PriceChange({
    required this.merchant,
    required this.category,
    required this.previous,
    required this.current,
    required this.since,
  });

  final String merchant;
  final TransactionCategory category;

  /// Previous and latest charge, as positive amounts.
  final Money previous;
  final Money current;

  /// Date of the latest, higher charge.
  final DateTime since;

  double get rate => current.cents / previous.cents - 1;

  /// Extra cost over a year if the charge stays monthly.
  Money get yearlyImpact => Money.cents((current.cents - previous.cents) * 12);
}

/// Finds recurring charges that went up, from the transactions alone: two
/// charges from the same merchant about a month apart, the later one at
/// least 2 % and CHF 1 higher. Shopping, food and transport vary by nature
/// and are left out.
abstract final class PriceChangeDetector {
  static const minRate = .02;
  static const minIncrease = Money.cents(100);

  /// Days between two charges that count as "monthly".
  static const minGapDays = 20;
  static const maxGapDays = 45;

  /// Increases older than this are no longer news.
  static const freshDays = 45;

  static const _recurring = {
    TransactionCategory.utilities,
    TransactionCategory.insurance,
    TransactionCategory.housing,
    TransactionCategory.other,
  };

  static List<PriceChange> detect(
    List<FinancialTransaction> transactions, {
    required DateTime now,
  }) {
    final byMerchant = <String, List<FinancialTransaction>>{};
    for (final item in transactions) {
      if (!item.amount.isNegative) continue;
      if (!_recurring.contains(item.category) &&
          !_isSubscription(item.merchant)) {
        continue;
      }
      byMerchant
          .putIfAbsent(item.merchant.trim().toLowerCase(), () => [])
          .add(item);
    }
    final changes = <PriceChange>[];
    for (final charges in byMerchant.values) {
      if (charges.length < 2) continue;
      charges.sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
      final latest = charges[0];
      final before = charges[1];
      final gap = latest.bookedAt.difference(before.bookedAt).inDays;
      if (gap < minGapDays || gap > maxGapDays) continue;
      if (now.difference(latest.bookedAt).inDays > freshDays) continue;
      final current = latest.amount.abs();
      final previous = before.amount.abs();
      if (previous.cents == 0) continue;
      final increase = current.cents - previous.cents;
      if (increase < minIncrease.cents) continue;
      if (increase / previous.cents < minRate) continue;
      changes.add(
        PriceChange(
          merchant: latest.merchant,
          category: latest.category,
          previous: previous,
          current: current,
          since: latest.bookedAt,
        ),
      );
    }
    changes.sort((a, b) => b.yearlyImpact.cents.compareTo(a.yearlyImpact.cents));
    return changes;
  }

  /// Streaming and similar services are often booked as shopping.
  static bool _isSubscription(String merchant) => const {
    'netflix',
    'spotify',
    'disney+',
    'apple',
    'google',
    'youtube',
    'dazn',
  }.any((name) => merchant.toLowerCase().contains(name));
}
