import 'package:finora/domain/merchant_categories.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/statement_import.dart';

/// An account whose bookings come from a statement the user imported. It
/// stays on the device.
class ImportedAccount {
  const ImportedAccount({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.balance,
    required this.importedAt,
    required this.transactions,
  });

  /// Builds an account from a parsed statement.
  factory ImportedAccount.fromStatement({
    required String institutionId,
    required String name,
    required ParsedStatement statement,
    required Money balance,
    required DateTime importedAt,
  }) {
    final id = idFor(institutionId, name);
    return ImportedAccount(
      id: id,
      institutionId: institutionId,
      name: name,
      balance: balance,
      importedAt: importedAt,
      transactions: [
        for (final (index, row) in statement.rows.indexed)
          FinancialTransaction(
            id: '$id-${row.date.millisecondsSinceEpoch}-$index',
            accountId: id,
            merchant: MerchantCategories.merchantName(row.text),
            category: MerchantCategories.categorize(row.text, row.amount),
            bookedAt: row.date,
            amount: row.amount,
          ),
      ],
    );
  }

  static String idFor(String institutionId, String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return 'import-$institutionId-${slug.isEmpty ? 'account' : slug}';
  }

  final String id;
  final String institutionId;
  final String name;

  /// Balance today, as entered or read from the statement.
  final Money balance;
  final DateTime importedAt;

  /// Oldest first.
  final List<FinancialTransaction> transactions;

  /// Adds the bookings of a newer import; a booking already known (same
  /// day, amount and merchant) is kept once.
  ImportedAccount merge(ImportedAccount newer) {
    String key(FinancialTransaction item) =>
        '${item.bookedAt.toIso8601String()}|${item.amount.cents}|${item.merchant}';
    final known = {for (final item in transactions) key(item)};
    final added = [
      for (final item in newer.transactions)
        if (!known.contains(key(item)))
          FinancialTransaction(
            id: '${item.id}-m',
            accountId: id,
            merchant: item.merchant,
            category: item.category,
            bookedAt: item.bookedAt,
            amount: item.amount,
          ),
    ];
    return ImportedAccount(
      id: id,
      institutionId: institutionId,
      name: name,
      balance: newer.balance,
      importedAt: newer.importedAt,
      transactions: [...transactions, ...added]
        ..sort((a, b) => a.bookedAt.compareTo(b.bookedAt)),
    );
  }

  FinancialAccount toAccount(DateTime now) => FinancialAccount(
    id: id,
    institutionId: institutionId,
    name: name,
    type: FinancialProductType.currentAccount,
    balance: balance,
    maskedIdentifier: 'CSV',
    monthlyChange: ImportedAnalytics.averageMonthlyNet(this, now),
  );

  /// Balance at the end of [day], from today's balance and the bookings
  /// since.
  Money balanceOn(DateTime day) {
    final end = DateTime(day.year, day.month, day.day + 1);
    final later = Money.sum([
      for (final item in transactions)
        if (!item.bookedAt.isBefore(end)) item.amount,
    ]);
    return balance - later;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'institutionId': institutionId,
    'name': name,
    'balance': balance.cents,
    'importedAt': importedAt.toIso8601String(),
    'transactions': [
      for (final item in transactions)
        {
          'd': item.bookedAt.toIso8601String().substring(0, 10),
          'm': item.merchant,
          'c': item.category.name,
          'a': item.amount.cents,
        },
    ],
  };

  static ImportedAccount? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final institutionId = raw['institutionId'];
    final name = raw['name'];
    final balance = raw['balance'];
    final importedAt = DateTime.tryParse('${raw['importedAt']}');
    if (id is! String ||
        institutionId is! String ||
        name is! String ||
        balance is! int ||
        importedAt == null) {
      return null;
    }
    final transactions = <FinancialTransaction>[];
    if (raw['transactions'] case final List items) {
      for (final (index, item) in items.indexed) {
        if (item is! Map) continue;
        final date = DateTime.tryParse('${item['d']}');
        final cents = item['a'];
        if (date == null || cents is! int) continue;
        transactions.add(
          FinancialTransaction(
            id: '$id-$index',
            accountId: id,
            merchant: '${item['m'] ?? ''}',
            category: TransactionCategory.values
                    .where((value) => value.name == item['c'])
                    .firstOrNull ??
                TransactionCategory.other,
            bookedAt: date,
            amount: Money.cents(cents),
          ),
        );
      }
    }
    return ImportedAccount(
      id: id,
      institutionId: institutionId,
      name: name,
      balance: Money.cents(balance),
      importedAt: importedAt,
      transactions: transactions,
    );
  }
}

/// Analytics for an imported account, computed from its bookings.
abstract final class ImportedAnalytics {
  static const _categoryColors = {
    TransactionCategory.housing: 0xFF027DB9,
    TransactionCategory.groceries: 0xFF014164,
    TransactionCategory.utilities: 0xFF8899A2,
    TransactionCategory.shopping: 0xFF5FB3DE,
    TransactionCategory.insurance: 0xFFB7C4CB,
    TransactionCategory.transport: 0xFFD9D4D1,
    TransactionCategory.dining: 0xFF3F8FB5,
    TransactionCategory.other: 0xFFC9C3BF,
    TransactionCategory.income: 0xFF12805C,
  };

  static DateTime _month(DateTime date) => DateTime(date.year, date.month);

  static bool _inMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  /// Complete months with bookings, newest first, at most three.
  static List<DateTime> _recentCompleteMonths(
    ImportedAccount account,
    DateTime now,
  ) {
    final current = _month(now);
    final months = <DateTime>{
      for (final item in account.transactions)
        if (_month(item.bookedAt).isBefore(current)) _month(item.bookedAt),
    }.toList()..sort((a, b) => b.compareTo(a));
    return months.take(3).toList();
  }

  static Money averageMonthlyNet(ImportedAccount account, DateTime now) {
    final months = _recentCompleteMonths(account, now);
    if (months.isEmpty) return Money.zero;
    final net = Money.sum([
      for (final item in account.transactions)
        if (months.any((month) => _inMonth(item.bookedAt, month))) item.amount,
    ]);
    return Money.cents((net.cents / months.length).round());
  }

  static AccountAnalytics build(
    ImportedAccount account, {
    required DateTime now,
    int historyMonths = 6,
  }) {
    final transactions = account.transactions;
    if (transactions.isEmpty) return const AccountAnalytics.empty();
    final current = _month(now);
    final firstMonth = _month(transactions.first.bookedAt);

    // Closing balance per month, rolled back from today's balance.
    final balanceHistory = [
      for (var back = historyMonths - 1; back >= 0; back--)
        () {
          final month = DateTime(current.year, current.month - back);
          final end = back == 0
              ? now
              : DateTime(month.year, month.month + 1, 0);
          return BalanceHistoryPoint(
            month: month,
            balance: account.balanceOn(end),
          );
        }(),
    ];

    Money incomeIn(DateTime month) => Money.sum([
      for (final item in transactions)
        if (_inMonth(item.bookedAt, month) && !item.amount.isNegative)
          item.amount,
    ]);
    Money spendingIn(DateTime month) => Money.sum([
      for (final item in transactions)
        if (_inMonth(item.bookedAt, month) && item.amount.isNegative)
          item.amount.abs(),
    ]);

    final cashFlow = <CashFlowPoint>[];
    for (
      var month = firstMonth;
      !month.isAfter(current);
      month = DateTime(month.year, month.month + 1)
    ) {
      if (current.difference(month).inDays > 31 * 24) continue;
      cashFlow.add(
        CashFlowPoint(
          month: month,
          income: incomeIn(month),
          spending: spendingIn(month),
        ),
      );
    }

    final recent = _recentCompleteMonths(account, now);
    final basis = recent.isEmpty ? [current] : recent;
    Money average(Money Function(DateTime) of) => Money.cents(
      (Money.sum(basis.map(of)).cents / basis.length).round(),
    );

    final byCategory = <TransactionCategory, int>{};
    for (final item in transactions) {
      if (!item.amount.isNegative) continue;
      if (!basis.any((month) => _inMonth(item.bookedAt, month))) continue;
      byCategory[item.category] =
          (byCategory[item.category] ?? 0) + item.amount.cents.abs();
    }
    final categories = [
      for (final entry in byCategory.entries)
        SpendingCategory(
          category: entry.key,
          amount: Money.cents((entry.value / basis.length).round()),
          colorValue: _categoryColors[entry.key] ?? 0xFFC9C3BF,
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    return AccountAnalytics(
      monthlyIncome: average(incomeIn),
      monthlySpending: average(spendingIn),
      balanceHistory: balanceHistory,
      cashFlowHistory: cashFlow,
      recurringPayments: recurring(account, now: now),
      spendingCategories: categories,
    );
  }

  /// Bills paid in at least three of the last six months for a similar
  /// amount (within 15 %), that Finora knows how to track.
  static List<RecurringPayment> recurring(
    ImportedAccount account, {
    required DateTime now,
  }) {
    final since = DateTime(now.year, now.month - 6);
    final byMerchant = <String, List<FinancialTransaction>>{};
    for (final item in account.transactions) {
      if (!item.amount.isNegative || item.bookedAt.isBefore(since)) continue;
      byMerchant.putIfAbsent(item.merchant, () => []).add(item);
    }
    final payments = <RecurringPayment>[];
    for (final MapEntry(key: merchant, value: items) in byMerchant.entries) {
      final category = MerchantCategories.billCategory(merchant);
      if (category == null) continue;
      final months = {for (final item in items) _month(item.bookedAt)};
      if (months.length < 3) continue;
      final amounts = [for (final item in items) item.amount.cents.abs()]
        ..sort();
      final median = amounts[amounts.length ~/ 2];
      final similar = items
          .where(
            (item) => (item.amount.cents.abs() - median).abs() <= median * .15,
          )
          .toList();
      if (similar.length < 3) continue;
      final last = similar.last;
      var next = DateTime(
        last.bookedAt.year,
        last.bookedAt.month + 1,
        last.bookedAt.day,
      );
      while (next.isBefore(now)) {
        next = DateTime(next.year, next.month + 1, next.day);
      }
      payments.add(
        RecurringPayment(
          merchant: merchant,
          category: category,
          amount: last.amount,
          cadence: BillCadence.monthly,
          nextDueAt: next,
        ),
      );
    }
    payments.sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    return payments;
  }
}
