import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';

/// Encodes domain objects the way `docs/api.md` describes, so the demo
/// data can be served by the reference backend and decoded again by
/// `ApiJson`. It is the mirror of `lib/data/api/json_mapping.dart`.
abstract final class ApiEncoding {
  static Map<String, Object?> money(Money value) => {
    'cents': value.cents,
    'currency': value.currency,
  };

  static String _date(DateTime value) => value.toIso8601String();

  static Map<String, Object?> institution(Institution value) => {
    'id': value.id,
    'name': value.name,
    'shortName': value.shortName,
    'color': value.colorValue,
    'connectionMethod': value.connectionMethod.name,
    'productTypes': [for (final type in value.productTypes) type.name],
  };

  static Map<String, Object?> connection(InstitutionConnection value) => {
    'institutionId': value.institutionId,
    'status': value.status.name,
    'lastSyncedAt': _date(value.lastSyncedAt),
  };

  static Map<String, Object?> account(FinancialAccount value) => {
    'id': value.id,
    'institutionId': value.institutionId,
    'name': value.name,
    'type': value.type.name,
    'balance': money(value.balance),
    'maskedIdentifier': value.maskedIdentifier,
    'monthlyChange': money(value.monthlyChange),
  };

  static Map<String, Object?> transaction(FinancialTransaction value) => {
    'id': value.id,
    'accountId': value.accountId,
    'merchant': value.merchant,
    'category': value.category.name,
    'bookedAt': _date(value.bookedAt),
    'amount': money(value.amount),
  };

  static Map<String, Object?> analytics(AccountAnalytics value) => {
    'monthlyIncome': money(value.monthlyIncome),
    'monthlySpending': money(value.monthlySpending),
    'balanceHistory': [
      for (final point in value.balanceHistory)
        {'month': _date(point.month), 'balance': money(point.balance)},
    ],
    'cashFlowHistory': [
      for (final point in value.cashFlowHistory)
        {
          'month': _date(point.month),
          'income': money(point.income),
          'spending': money(point.spending),
        },
    ],
    'recurringPayments': [
      for (final bill in value.recurringPayments)
        {
          'merchant': bill.merchant,
          'category': bill.category.name,
          'amount': money(bill.amount),
          'cadence': bill.cadence.name,
          'nextDueAt': _date(bill.nextDueAt),
        },
    ],
    'spendingCategories': [
      for (final category in value.spendingCategories)
        {
          'category': category.category.name,
          'amount': money(category.amount),
          'color': category.colorValue,
        },
    ],
  };

  static Map<String, Object?> taxYear(TaxYearData value) => {
    'year': value.year,
    'asOf': _date(value.asOf),
    'isComplete': value.isComplete,
    'pillar3aContributions': money(value.pillar3aContributions),
    'accounts': [
      for (final figures in value.accounts)
        {
          'accountId': figures.account.id,
          'closingBalance': money(figures.closingBalance),
          'income': money(figures.income),
          'interestPaid': money(figures.interestPaid),
        },
    ],
  };

  /// The fixture served by the reference backend: the full demo profile
  /// (with Raiffeisen for the mortgage) on 23 October 2026.
  static Future<Map<String, Object?>> demoFixture(DateTime now) async {
    final repository = MockFinancialRepository(
      institutionIds: {...InstitutionCatalogue.demoInstitutionIds, 'raiffeisen'},
      products: FinancialProductType.values.toSet(),
      clock: () => now,
    );
    final accounts = await repository.getAccounts();
    return {
      'generatedFor': _date(now),
      'institutions': [
        for (final item in await repository.getInstitutions()) institution(item),
      ],
      'connections': [
        for (final item in await repository.getConnections()) connection(item),
      ],
      'accounts': [for (final item in accounts) account(item)],
      'analytics': {
        for (final item in accounts)
          item.id: analytics(
            await repository.getAccountAnalytics(item.id, historyMonths: 24),
          ),
      },
      'transactions': [
        for (final item in await repository.getTransactions()) transaction(item),
      ],
      'pillar3aContributions': {
        for (final year in [now.year - 1, now.year])
          '$year': money(await repository.getPillar3aContributions(year: year)),
      },
      'tax': {
        for (final year in [now.year - 1, now.year])
          '$year': taxYear(await repository.getTaxYearData(year)),
      },
    };
  }
}
