import 'package:finora/data/api/api_client.dart';
import 'package:finora/data/api/json_mapping.dart';
import 'package:finora/domain/financial_repository.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';

/// [FinancialRepository] backed by the Finora backend-for-frontend. The
/// backend aggregates bLink (banks) and OpenWealth (portfolios) with the
/// user's consent; this class only maps its JSON to the domain.
class RemoteFinancialRepository implements FinancialRepository {
  RemoteFinancialRepository(this._api);

  final FinoraApiClient _api;

  /// Malformed data is reported like any other backend failure, so the UI
  /// shows its usual "unavailable" state instead of crashing.
  Future<T> _read<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FormatException catch (error) {
      throw ApiException(200, 'Unexpected data: ${error.message}');
    }
  }

  Future<List<T>> _list<T>(
    String path,
    T Function(Object?) parse, {
    Map<String, String>? query,
  }) => _read(() async {
    final raw = await _api.get(path, query: query);
    return [for (final item in ApiJson.list(raw, path)) parse(item)];
  });

  @override
  Future<List<Institution>> getInstitutions() =>
      _list('v1/institutions', ApiJson.institution);

  @override
  Future<List<InstitutionConnection>> getConnections() =>
      _list('v1/connections', ApiJson.connection);

  @override
  Future<List<FinancialAccount>> getAccounts() =>
      _list('v1/accounts', ApiJson.account);

  @override
  Future<AccountAnalytics> getAccountAnalytics(
    String accountId, {
    int historyMonths = 6,
  }) => _read(
    () async => ApiJson.analytics(
      await _api.get(
        'v1/accounts/${Uri.encodeComponent(accountId)}/analytics',
        query: {'months': '$historyMonths'},
      ),
    ),
  );

  @override
  Future<List<FinancialTransaction>> getTransactions({String? accountId}) =>
      _list(
        'v1/transactions',
        ApiJson.transaction,
        query: accountId == null ? null : {'accountId': accountId},
      );

  @override
  Future<Money> getPillar3aContributions({required int year}) => _read(() async {
    final raw = await _api.get(
      'v1/pillar3a/contributions',
      query: {'year': '$year'},
    );
    if (raw is! Map) throw const FormatException('Expected an object');
    return ApiJson.money(raw['amount'], 'amount');
  });

  @override
  Future<TaxYearData> getTaxYearData(int year) => _read(() async {
    final accounts = await getAccounts();
    return ApiJson.taxYear(await _api.get('v1/tax/$year'), {
      for (final account in accounts) account.id: account,
    });
  });

  @override
  Future<void> refresh() async {
    await _api.post('v1/refresh');
  }
}
