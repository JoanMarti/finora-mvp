import 'package:finora/domain/financial_repository.dart';
import 'package:finora/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final financialRepositoryProvider = Provider<FinancialRepository>(
  (ref) => MockFinancialRepository(),
);

final institutionsProvider = FutureProvider(
  (ref) => ref.watch(financialRepositoryProvider).getInstitutions(),
);
final connectionsProvider = FutureProvider(
  (ref) => ref.watch(financialRepositoryProvider).getConnections(),
);
final accountsProvider = FutureProvider(
  (ref) => ref.watch(financialRepositoryProvider).getAccounts(),
);
final overviewProvider = FutureProvider(
  (ref) => ref.watch(financialRepositoryProvider).getOverview(),
);
final transactionsProvider = FutureProvider.family(
  (ref, String? accountId) => ref
      .watch(financialRepositoryProvider)
      .getTransactions(accountId: accountId),
);

class MockFinancialRepository implements FinancialRepository {
  static const institutions = <Institution>[
    Institution(
      id: 'ubs',
      name: 'UBS',
      shortName: 'UBS',
      colorValue: 0xFFE60000,
    ),
    Institution(
      id: 'zkb',
      name: 'Zürcher Kantonalbank',
      shortName: 'ZKB',
      colorValue: 0xFF1377B8,
    ),
    Institution(
      id: 'swissquote',
      name: 'Swissquote',
      shortName: 'SQ',
      colorValue: 0xFFEB232B,
    ),
    Institution(
      id: 'frankly',
      name: 'frankly',
      shortName: 'fr',
      colorValue: 0xFF111111,
    ),
  ];

  static const accounts = <FinancialAccount>[
    FinancialAccount(
      id: 'ubs-personal',
      institutionId: 'ubs',
      name: 'Personal account',
      type: FinancialProductType.currentAccount,
      balance: Money(8420.35),
      maskedIdentifier: '•••• 8472',
      change: 1250,
    ),
    FinancialAccount(
      id: 'ubs-savings',
      institutionId: 'ubs',
      name: 'Savings',
      type: FinancialProductType.savings,
      balance: Money(20000),
      maskedIdentifier: '•••• 1209',
      change: 300,
    ),
    FinancialAccount(
      id: 'zkb-private',
      institutionId: 'zkb',
      name: 'Private account',
      type: FinancialProductType.currentAccount,
      balance: Money(16400.05),
      maskedIdentifier: '•••• 3601',
      change: -482.4,
    ),
    FinancialAccount(
      id: 'swissquote-portfolio',
      institutionId: 'swissquote',
      name: 'Investment portfolio',
      type: FinancialProductType.investments,
      balance: Money(42300),
      maskedIdentifier: 'Portfolio 1847',
      change: 1840.2,
    ),
    FinancialAccount(
      id: 'frankly-3a',
      institutionId: 'frankly',
      name: 'Pillar 3a',
      type: FinancialProductType.pillar3a,
      balance: Money(29360),
      maskedIdentifier: '3a portfolio',
      change: 510.8,
    ),
  ];

  static const transactions = <FinancialTransaction>[
    FinancialTransaction(
      id: 't1',
      accountId: 'ubs-personal',
      merchant: 'Migros',
      category: 'Groceries',
      dateLabel: 'Today',
      amount: Money(-86.40),
    ),
    FinancialTransaction(
      id: 't2',
      accountId: 'ubs-personal',
      merchant: 'SBB Mobile',
      category: 'Transport',
      dateLabel: 'Yesterday',
      amount: Money(-42),
    ),
    FinancialTransaction(
      id: 't3',
      accountId: 'ubs-personal',
      merchant: 'Salary',
      category: 'Income',
      dateLabel: '15 Sep',
      amount: Money(6850),
    ),
    FinancialTransaction(
      id: 't4',
      accountId: 'zkb-private',
      merchant: 'Swisscom',
      category: 'Utilities',
      dateLabel: '14 Sep',
      amount: Money(-89.90),
    ),
    FinancialTransaction(
      id: 't5',
      accountId: 'ubs-personal',
      merchant: 'Coop City',
      category: 'Shopping',
      dateLabel: '12 Sep',
      amount: Money(-154.25),
    ),
  ];

  @override
  Future<List<FinancialAccount>> getAccounts() async => accounts;

  @override
  Future<List<InstitutionConnection>> getConnections() async => const [
    InstitutionConnection(
      institutionId: 'ubs',
      status: ConnectionStatus.connected,
      lastSyncLabel: 'Updated 4 min ago',
    ),
    InstitutionConnection(
      institutionId: 'zkb',
      status: ConnectionStatus.stale,
      lastSyncLabel: 'Updated yesterday',
    ),
    InstitutionConnection(
      institutionId: 'swissquote',
      status: ConnectionStatus.connected,
      lastSyncLabel: 'Updated 12 min ago',
    ),
    InstitutionConnection(
      institutionId: 'frankly',
      status: ConnectionStatus.manual,
      lastSyncLabel: 'Manual value · 3 days ago',
    ),
  ];

  @override
  Future<List<Institution>> getInstitutions() async => institutions;

  @override
  Future<FinancialOverview> getOverview() async => const FinancialOverview(
    total: Money(116480.40),
    cash: Money(44820.40),
    investments: Money(42300),
    retirement: Money(29360),
    monthlyChange: 3.1,
  );

  @override
  Future<List<FinancialTransaction>> getTransactions({
    String? accountId,
  }) async {
    if (accountId == null) return transactions;
    return transactions.where((item) => item.accountId == accountId).toList();
  }

  @override
  Future<void> refresh() =>
      Future<void>.delayed(const Duration(milliseconds: 600));
}
