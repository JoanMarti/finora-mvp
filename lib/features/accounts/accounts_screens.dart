import 'package:finora/app/theme.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final institutions =
        ref.watch(institutionsProvider).value ?? const <Institution>[];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Accounts'),
      ),
      body: SafeArea(
        top: false,
        child: FinoraPage(
          child: accounts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: Text('Accounts are temporarily unavailable.'),
            ),
            data: (items) => ListView(
              children: [
                Text(
                  'Everything you own',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${items.length} accounts · CHF is your display currency',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                for (final institution in institutions) ...[
                  if (items.any((item) => item.institutionId == institution.id))
                    SectionTitle(institution.name),
                  for (final account in items.where(
                    (item) => item.institutionId == institution.id,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: InstitutionBadge(institution: institution),
                          title: Text(
                            account.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${account.type.label} · ${account.maskedIdentifier}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatMoney(account.balance),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${account.change >= 0 ? '+' : '−'} CHF ${account.change.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: account.change >= 0
                                      ? finoraGreen
                                      : Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => context.push('/account/${account.id}'),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => context.push('/connect'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add an institution'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InstitutionDetailScreen extends ConsumerWidget {
  const InstitutionDetailScreen({required this.institutionId, super.key});
  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutions = ref.watch(institutionsProvider).value;
    final accounts = ref.watch(accountsProvider).value;
    final connections = ref.watch(connectionsProvider).value;
    if (institutions == null || accounts == null || connections == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final institution = institutions
        .where((item) => item.id == institutionId)
        .firstOrNull;
    if (institution == null) {
      return const _NotFound(label: 'Institution not found');
    }
    final owned = accounts
        .where((item) => item.institutionId == institutionId)
        .toList();
    final connection = connections
        .where((item) => item.institutionId == institutionId)
        .firstOrNull;
    final total = owned.fold<double>(
      0,
      (sum, item) => sum + item.balance.amount,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(institution.name),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            Center(child: InstitutionBadge(institution: institution, size: 68)),
            const SizedBox(height: 16),
            Center(
              child: Text(
                institution.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                formatMoney(Money(total)),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (connection != null)
              Card(
                color: connection.status == ConnectionStatus.stale
                    ? const Color(0xFFFFF4DD)
                    : finoraMint,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      StatusPill(status: connection.status),
                      const Spacer(),
                      Text(
                        connection.lastSyncLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF66756F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SectionTitle('Accounts'),
            for (final account in owned)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    title: Text(
                      account.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(account.maskedIdentifier),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatMoney(account.balance),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push('/account/${account.id}'),
                  ),
                ),
              ),
            const SectionTitle('Connection'),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('Read-only access'),
                    subtitle: Text('Balances and transactions only'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Refresh data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => ref.invalidate(accountsProvider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({required this.accountId, super.key});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value;
    final institutions = ref.watch(institutionsProvider).value;
    final transactions = ref.watch(transactionsProvider(accountId)).value;
    if (accounts == null || institutions == null || transactions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final account = accounts.where((item) => item.id == accountId).firstOrNull;
    if (account == null) return const _NotFound(label: 'Account not found');
    final institution = institutions
        .where((item) => item.id == account.institutionId)
        .first;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(account.name),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            Card(
              color: finoraInk,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InstitutionBadge(institution: institution),
                        const SizedBox(width: 12),
                        Text(
                          institution.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      account.name,
                      style: const TextStyle(color: Color(0xFFAABBB5)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatMoney(account.balance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      account.maskedIdentifier,
                      style: const TextStyle(color: Color(0xFFAABBB5)),
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('This month'),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Money in',
                    value: '+ CHF 6,850',
                    positive: true,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _Metric(
                    label: 'Money out',
                    value: '− CHF 1,492',
                    positive: false,
                  ),
                ),
              ],
            ),
            const SectionTitle('Recent transactions'),
            Card(
              child: transactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No recent transactions')),
                    )
                  : Column(
                      children: [
                        for (final item in transactions)
                          TransactionTile(transaction: item),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            const Card(
              color: finoraMint,
              child: ListTile(
                leading: Icon(Icons.open_in_new, color: finoraGreen),
                title: Text(
                  'Need to make a payment?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Finora is read-only. Continue in your bank app.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.positive,
  });
  final String label;
  final String value;
  final bool positive;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7974))),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: positive ? finoraGreen : finoraInk,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}
