import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class InstitutionDetailScreen extends ConsumerWidget {
  const InstitutionDetailScreen({required this.institutionId, super.key});
  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutions = ref.watch(institutionsProvider).value;
    final accounts = ref.watch(accountsProvider).value;
    final connections = ref.watch(connectionsProvider).value;
    final now = ref.watch(clockProvider)();
    if (institutions == null || accounts == null || connections == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final institution = institutions
        .where((item) => item.id == institutionId)
        .firstOrNull;
    if (institution == null) {
      return const NotFoundScreen(label: 'Institution not found');
    }
    final owned = accounts
        .where((item) => item.institutionId == institutionId)
        .toList();
    final connection = connections
        .where((item) => item.institutionId == institutionId)
        .firstOrNull;
    final total = Money.sum(owned.map((item) => item.balance));

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
                formatMoney(total),
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
                    ? const Color(0xFFFFF5DF)
                    : finoraMint,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      StatusPill(status: connection.status),
                      const Spacer(),
                      Text(
                        formatSyncTime(connection.lastSyncedAt, now),
                        style: const TextStyle(
                          fontSize: 12,
                          color: finoraMutedInk,
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
                    onTap: () => refreshFinancialData(ref),
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
