import 'package:finora/domain/models.dart';

/// Read-only access to the user's financial data, independent of the source
/// (bLink, OpenWealth, manual values or the demo implementation).
abstract interface class FinancialRepository {
  /// Institutions the user has connected.
  Future<List<Institution>> getInstitutions();
  Future<List<InstitutionConnection>> getConnections();
  Future<List<FinancialAccount>> getAccounts();
  Future<AccountAnalytics> getAccountAnalytics(String accountId);

  /// Transactions sorted from newest to oldest.
  Future<List<FinancialTransaction>> getTransactions({String? accountId});

  /// Pillar 3a contributions booked in [year] across all providers.
  Future<Money> getPillar3aContributions({required int year});

  /// Asks every connected source for fresh data.
  Future<void> refresh();
}
