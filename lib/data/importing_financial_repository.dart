import 'package:finora/domain/category_rules.dart';
import 'package:finora/domain/financial_repository.dart';
import 'package:finora/domain/imported_accounts.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';

/// Adds the accounts imported from statements to another repository. An
/// imported account replaces the current account of the same bank that
/// the other source would show.
class ImportingFinancialRepository implements FinancialRepository {
  ImportingFinancialRepository(
    this._base, {
    required List<ImportedAccount> imported,
    this.categoryRules = const {},
    this.clock = DateTime.now,
  }) : imported = [
         for (final account in imported) account.withRules(categoryRules),
       ];

  final FinancialRepository _base;
  /// Imported accounts, with the user's categories applied.
  final List<ImportedAccount> imported;

  /// Categories the user chose, by merchant; applied to every booking.
  final Map<String, TransactionCategory> categoryRules;
  final DateTime Function() clock;

  List<ImportedAccount> get _imported => imported;
  DateTime _clock() => clock();

  Set<String> get _importedInstitutions => {
    for (final account in _imported) account.institutionId,
  };

  bool _replaced(FinancialAccount account) =>
      account.type == FinancialProductType.currentAccount &&
      _importedInstitutions.contains(account.institutionId);

  ImportedAccount? _importedById(String id) =>
      _imported.where((account) => account.id == id).firstOrNull;

  @override
  Future<List<Institution>> getInstitutions() async {
    final base = await _base.getInstitutions();
    final known = {for (final institution in base) institution.id};
    return [
      ...base,
      for (final id in _importedInstitutions)
        if (!known.contains(id)) ?InstitutionCatalogue.byId(id),
    ];
  }

  @override
  Future<List<InstitutionConnection>> getConnections() async {
    final base = await _base.getConnections();
    final known = {for (final connection in base) connection.institutionId};
    return [
      ...base,
      for (final account in _imported)
        if (!known.contains(account.institutionId))
          InstitutionConnection(
            institutionId: account.institutionId,
            status: ConnectionStatus.manual,
            lastSyncedAt: account.importedAt,
          ),
    ];
  }

  @override
  Future<List<FinancialAccount>> getAccounts() async {
    final now = _clock();
    return [
      for (final account in await _base.getAccounts())
        if (!_replaced(account)) account,
      for (final account in _imported) account.toAccount(now),
    ];
  }

  @override
  Future<AccountAnalytics> getAccountAnalytics(
    String accountId, {
    int historyMonths = 6,
  }) async {
    final imported = _importedById(accountId);
    if (imported != null) {
      return ImportedAnalytics.build(
        imported,
        now: _clock(),
        historyMonths: historyMonths,
      );
    }
    return _base.getAccountAnalytics(accountId, historyMonths: historyMonths);
  }

  @override
  Future<List<FinancialTransaction>> getTransactions({
    String? accountId,
  }) async {
    if (accountId != null) {
      final imported = _importedById(accountId);
      if (imported != null) return imported.transactions.reversed.toList();
      return CategoryRules.applyAll(
        await _base.getTransactions(accountId: accountId),
        categoryRules,
      );
    }
    final replacedIds = {
      for (final account in await _base.getAccounts())
        if (_replaced(account)) account.id,
    };
    final items = [
      for (final item in await _base.getTransactions())
        if (!replacedIds.contains(item.accountId))
          CategoryRules.apply(item, categoryRules),
      for (final account in _imported) ...account.transactions,
    ]..sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
    return items;
  }

  @override
  Future<Money> getPillar3aContributions({required int year}) =>
      _base.getPillar3aContributions(year: year);

  @override
  Future<TaxYearData> getTaxYearData(int year) async {
    final base = await _base.getTaxYearData(year);
    final now = _clock();
    return TaxYearData(
      year: base.year,
      asOf: base.asOf,
      isComplete: base.isComplete,
      pillar3aContributions: base.pillar3aContributions,
      accounts: [
        for (final item in base.accounts)
          if (!_replaced(item.account)) item,
        for (final account in _imported)
          TaxAccountFigures(
            account: account.toAccount(now),
            closingBalance: base.isComplete
                ? account.balanceOn(DateTime(year, 12, 31))
                : account.balance,
            income: Money.zero,
            interestPaid: Money.zero,
          ),
      ],
    );
  }

  @override
  Future<void> refresh() => _base.refresh();
}
