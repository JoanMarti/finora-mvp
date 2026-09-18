import 'package:finora/domain/models.dart';

abstract interface class FinancialRepository {
  Future<List<Institution>> getInstitutions();
  Future<List<InstitutionConnection>> getConnections();
  Future<List<FinancialAccount>> getAccounts();
  Future<FinancialOverview> getOverview();
  Future<List<FinancialTransaction>> getTransactions({String? accountId});
  Future<void> refresh();
}
