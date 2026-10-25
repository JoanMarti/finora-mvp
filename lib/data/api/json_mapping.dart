import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';

/// Maps backend JSON (see `docs/api.md`) to domain objects. Money travels
/// as `{"cents": 12345, "currency": "CHF"}`, dates as ISO 8601 and enums by
/// name. Anything malformed throws a [FormatException].
abstract final class ApiJson {
  static Map<String, Object?> _map(Object? raw, String what) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map) return raw.cast<String, Object?>();
    throw FormatException('Expected an object for $what');
  }

  static List<Object?> list(Object? raw, String what) {
    if (raw is List) return raw;
    throw FormatException('Expected a list for $what');
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException('Missing text "$key"');
  }

  static T _enum<T extends Enum>(List<T> values, Object? name, String key) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown value "$name" for "$key"');
  }

  static DateTime _date(Map<String, Object?> json, String key) {
    final value = DateTime.tryParse('${json[key]}');
    if (value == null) throw FormatException('Missing date "$key"');
    return value;
  }

  static Money money(Object? raw, [String what = 'money']) {
    final json = _map(raw, what);
    final cents = json['cents'];
    if (cents is! int) throw FormatException('Missing cents in $what');
    return Money.cents(cents, currency: json['currency'] as String? ?? 'CHF');
  }

  static Institution institution(Object? raw) {
    final json = _map(raw, 'institution');
    return Institution(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      shortName: json['shortName'] as String? ?? _string(json, 'name'),
      colorValue: json['color'] as int? ?? 0xFF3C94FF,
      connectionMethod: _enum(
        ConnectionMethod.values,
        json['connectionMethod'],
        'connectionMethod',
      ),
      productTypes: {
        for (final type in list(json['productTypes'] ?? const [], 'types'))
          _enum(FinancialProductType.values, type, 'productTypes'),
      },
    );
  }

  static InstitutionConnection connection(Object? raw) {
    final json = _map(raw, 'connection');
    return InstitutionConnection(
      institutionId: _string(json, 'institutionId'),
      status: _enum(ConnectionStatus.values, json['status'], 'status'),
      lastSyncedAt: _date(json, 'lastSyncedAt'),
    );
  }

  static FinancialAccount account(Object? raw) {
    final json = _map(raw, 'account');
    return FinancialAccount(
      id: _string(json, 'id'),
      institutionId: _string(json, 'institutionId'),
      name: _string(json, 'name'),
      type: _enum(FinancialProductType.values, json['type'], 'type'),
      balance: money(json['balance'], 'balance'),
      maskedIdentifier: json['maskedIdentifier'] as String? ?? '',
      monthlyChange: json['monthlyChange'] == null
          ? Money.zero
          : money(json['monthlyChange'], 'monthlyChange'),
    );
  }

  static FinancialTransaction transaction(Object? raw) {
    final json = _map(raw, 'transaction');
    return FinancialTransaction(
      id: _string(json, 'id'),
      accountId: _string(json, 'accountId'),
      merchant: _string(json, 'merchant'),
      category: _enum(TransactionCategory.values, json['category'], 'category'),
      bookedAt: _date(json, 'bookedAt'),
      amount: money(json['amount'], 'amount'),
      foreignCurrency: json['foreignCurrency'] as String?,
    );
  }

  static AccountAnalytics analytics(Object? raw) {
    final json = _map(raw, 'analytics');
    return AccountAnalytics(
      monthlyIncome: money(json['monthlyIncome'], 'monthlyIncome'),
      monthlySpending: money(json['monthlySpending'], 'monthlySpending'),
      balanceHistory: [
        for (final item in list(json['balanceHistory'] ?? const [], 'history'))
          BalanceHistoryPoint(
            month: _date(_map(item, 'point'), 'month'),
            balance: money(_map(item, 'point')['balance']),
          ),
      ],
      cashFlowHistory: [
        for (final item in list(json['cashFlowHistory'] ?? const [], 'flow'))
          CashFlowPoint(
            month: _date(_map(item, 'point'), 'month'),
            income: money(_map(item, 'point')['income']),
            spending: money(_map(item, 'point')['spending']),
          ),
      ],
      recurringPayments: [
        for (final item in list(json['recurringPayments'] ?? const [], 'bills'))
          _recurring(_map(item, 'bill')),
      ],
      spendingCategories: [
        for (final item in list(json['spendingCategories'] ?? const [], 'cat'))
          SpendingCategory(
            category: _enum(
              TransactionCategory.values,
              _map(item, 'category')['category'],
              'category',
            ),
            amount: money(_map(item, 'category')['amount']),
            colorValue: _map(item, 'category')['color'] as int? ?? 0xFF3C94FF,
          ),
      ],
    );
  }

  static RecurringPayment _recurring(Map<String, Object?> json) =>
      RecurringPayment(
        merchant: _string(json, 'merchant'),
        category: _enum(BillCategory.values, json['category'], 'category'),
        amount: money(json['amount'], 'amount'),
        cadence: _enum(BillCadence.values, json['cadence'], 'cadence'),
        nextDueAt: _date(json, 'nextDueAt'),
      );

  /// Tax figures refer to accounts by id; [accounts] resolves them.
  static TaxYearData taxYear(
    Object? raw,
    Map<String, FinancialAccount> accounts,
  ) {
    final json = _map(raw, 'tax year');
    final year = json['year'];
    if (year is! int) throw const FormatException('Missing tax year');
    return TaxYearData(
      year: year,
      asOf: _date(json, 'asOf'),
      isComplete: json['isComplete'] as bool? ?? false,
      pillar3aContributions: money(
        json['pillar3aContributions'],
        'pillar3aContributions',
      ),
      accounts: [
        for (final item in list(json['accounts'] ?? const [], 'accounts'))
          if (accounts[_map(item, 'figures')['accountId']] case final account?)
            TaxAccountFigures(
              account: account,
              closingBalance: money(_map(item, 'figures')['closingBalance']),
              income: _map(item, 'figures')['income'] == null
                  ? Money.zero
                  : money(_map(item, 'figures')['income']),
              interestPaid: _map(item, 'figures')['interestPaid'] == null
                  ? Money.zero
                  : money(_map(item, 'figures')['interestPaid']),
            ),
      ],
    );
  }
}
