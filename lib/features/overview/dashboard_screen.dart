import 'package:finora/app/theme.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    final accounts = ref.watch(accountsProvider).value;
    final institutions = ref.watch(institutionsProvider).value;
    final transactions = ref.watch(transactionsProvider(null)).value;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(financialRepositoryProvider).refresh();
            ref.invalidate(overviewProvider);
            ref.invalidate(accountsProvider);
            ref.invalidate(transactionsProvider);
          },
          child: FinoraPage(
            child: ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Good morning, Joan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => ref.invalidate(overviewProvider),
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                    const CircleAvatar(
                      backgroundColor: finoraInk,
                      foregroundColor: Colors.white,
                      child: Text('JM'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                overview.when(
                  loading: () => const SizedBox(
                    height: 205,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Your overview is temporarily unavailable.'),
                    ),
                  ),
                  data: (data) => _BalanceHero(overview: data),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFFFF4DD),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFE2A8),
                      child: Icon(
                        Icons.sync_problem_outlined,
                        color: Color(0xFF8B5400),
                      ),
                    ),
                    title: const Text(
                      'One connection needs attention',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('ZKB was last updated yesterday'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/profile'),
                  ),
                ),
                if (accounts != null && institutions != null) ...[
                  SectionTitle(
                    'Institutions',
                    action: TextButton(
                      onPressed: () => context.go('/accounts'),
                      child: const Text('See all'),
                    ),
                  ),
                  ...institutions.map((institution) {
                    final owned = accounts
                        .where((item) => item.institutionId == institution.id)
                        .toList();
                    if (owned.isEmpty) return const SizedBox.shrink();
                    final total = owned.fold<double>(
                      0,
                      (sum, item) => sum + item.balance.amount,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: InstitutionBadge(institution: institution),
                          title: Text(
                            institution.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${owned.length} ${owned.length == 1 ? 'account' : 'accounts'}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatMoney(Money(total)),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Color(0xFF7A8782),
                              ),
                            ],
                          ),
                          onTap: () =>
                              context.push('/institution/${institution.id}'),
                        ),
                      ),
                    );
                  }),
                ],
                if (transactions != null) ...[
                  SectionTitle(
                    'Recent activity',
                    action: TextButton(
                      onPressed: () => context.go('/activity'),
                      child: const Text('See all'),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final item in transactions.take(3))
                          TransactionTile(transaction: item),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.overview});
  final FinancialOverview overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: finoraInk,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2412211E),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'TOTAL BALANCE',
                  style: TextStyle(
                    color: Color(0xFFAABBB5),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(Icons.visibility_outlined, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatMoney(overview.total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+${overview.monthlyChange}% this month · Updated 4 min ago',
            style: const TextStyle(
              color: Color(0xFF8FE0C2),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _Allocation(label: 'Cash', money: overview.cash),
              _Allocation(label: 'Investments', money: overview.investments),
              _Allocation(label: 'Pillar 3a', money: overview.retirement),
            ],
          ),
        ],
      ),
    );
  }
}

class _Allocation extends StatelessWidget {
  const _Allocation({required this.label, required this.money});
  final String label;
  final Money money;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFAABBB5), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          _compactMoney(money),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

String _compactMoney(Money money) =>
    '${money.currency} ${(money.amount / 1000).toStringAsFixed(1)}k';
