import 'dart:math' as math;

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

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({required this.accountId, super.key});
  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _showAllRecurring = false;
  bool _recurringMonitoring = true;
  bool _balanceAlerts = true;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value;
    final institutions = ref.watch(institutionsProvider).value;
    final transactions = ref
        .watch(transactionsProvider(widget.accountId))
        .value;
    final analytics = ref
        .watch(accountAnalyticsProvider(widget.accountId))
        .value;
    if (accounts == null ||
        institutions == null ||
        transactions == null ||
        analytics == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final account = accounts
        .where((item) => item.id == widget.accountId)
        .firstOrNull;
    if (account == null) return const _NotFound(label: 'Account not found');
    final institution = institutions
        .where((item) => item.id == account.institutionId)
        .first;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Account insight'),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            _AccountBalanceCard(account: account, institution: institution),
            if (analytics.balanceHistory.isNotEmpty) ...[
              const SectionTitle('Account health'),
              _BalanceEvolutionCard(analytics: analytics),
              const SectionTitle('Cash flow'),
              _CashFlowCard(analytics: analytics),
              SectionTitle(
                'Recurring payments',
                action: TextButton(
                  onPressed: () =>
                      setState(() => _showAllRecurring = !_showAllRecurring),
                  child: Text(_showAllRecurring ? 'Show less' : 'See all'),
                ),
              ),
              _RecurringPaymentsCard(
                analytics: analytics,
                showAll: _showAllRecurring,
              ),
              const SectionTitle('Potential improvements'),
              _OpportunityCard(
                icon: Icons.health_and_safety_outlined,
                accent: finoraAqua,
                eyebrow: 'COVERAGE CHECK · PARTNER OPTION',
                title: 'Review insurance in one place',
                description: 'Two insurance payments were detected. A guided comparison could reveal duplicated cover or a better deductible setup.',
                value: 'Illustrative potential: CHF 35–70 / month',
                actionLabel: 'Explore a coverage check',
                onPressed: () => _showServiceMessage(
                  'Coverage comparison would open only with your consent.',
                ),
              ),
              const SizedBox(height: 12),
              _OpportunityCard(
                icon: Icons.account_balance_outlined,
                accent: finoraPink,
                eyebrow: 'DEBT VIEW · OPTIONAL',
                title: 'See the true cost of your debt',
                description: 'No cards or loans are connected yet. Add them to compare rates and see whether consolidation deserves a closer look.',
                value: 'No savings estimate until debt data is available',
                actionLabel: 'Connect debt accounts',
                onPressed: () => context.push('/connect'),
              ),
              const SectionTitle('Monitoring'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.autorenew, color: finoraBlue),
                      title: const Text(
                        'Recurring payment changes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Alert me when a regular bill changes',
                      ),
                      value: _recurringMonitoring,
                      onChanged: (value) =>
                          setState(() => _recurringMonitoring = value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        color: finoraPink,
                      ),
                      title: const Text(
                        'Low balance forecast',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Warn me before planned bills put cash at risk',
                      ),
                      value: _balanceAlerts,
                      onChanged: (value) =>
                          setState(() => _balanceAlerts = value),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SectionTitle('Account health'),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'More history is needed before Finora can explain cash flow and recurring payments for this account.',
                  ),
                ),
              ),
            ],
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
              color: finoraSoftBlue,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: finoraBlue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Insights use mock transaction patterns and are not financial advice. Finora never applies for or switches a product without explicit consent.',
                        style: TextStyle(
                          color: Color(0xFF63718A),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountBalanceCard extends StatelessWidget {
  const _AccountBalanceCard({required this.account, required this.institution});

  final FinancialAccount account;
  final Institution institution;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: finoraInk,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InstitutionBadge(institution: institution),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        institution.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Updated 4 min ago',
                        style: TextStyle(
                          color: Color(0xFFAABBB5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              account.name,
              style: const TextStyle(color: Color(0xFFAABBB5)),
            ),
            const SizedBox(height: 5),
            Text(
              formatMoney(account.balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -.7,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    account.maskedIdentifier,
                    style: const TextStyle(color: Color(0xFFAABBB5)),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: finoraGreen.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '+ CHF 900 in Sep',
                          style: TextStyle(
                            color: Color(0xFF7DE2B9),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceEvolutionCard extends StatelessWidget {
  const _BalanceEvolutionCard({required this.analytics});
  final AccountAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final points = analytics.balanceHistory;
    final change = points.last.balance - points.first.balance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balance evolution',
                        style: TextStyle(
                          color: finoraInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Closing balance · last 6 months',
                        style: TextStyle(color: Color(0xFF8A98AB)),
                      ),
                    ],
                  ),
                ),
                _ValuePill(
                  label: '+ CHF ${change.toStringAsFixed(0)}',
                  color: finoraGreen,
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 128,
              width: double.infinity,
              child: CustomPaint(
                painter: _BalanceHistoryPainter(points: points),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final point in points)
                  Text(
                    point.label,
                    style: TextStyle(
                      color: point == points.last
                          ? finoraPink
                          : const Color(0xFF9AA8BC),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.analytics});
  final AccountAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final savingsRate = (analytics.savingsRate * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Income vs spending',
                    style: TextStyle(
                      color: finoraInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _ValuePill(label: '$savingsRate% kept', color: finoraBlue),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _CashFlowMetric(
                    label: 'INCOME',
                    value: formatMoney(analytics.monthlyIncome),
                    color: finoraGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CashFlowMetric(
                    label: 'SPENDING',
                    value: formatMoney(analytics.monthlySpending),
                    color: finoraPink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 112,
              width: double.infinity,
              child: CustomPaint(
                painter: _CashFlowPainter(points: analytics.cashFlowHistory),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final point in analytics.cashFlowHistory)
                  Text(
                    point.label,
                    style: const TextStyle(
                      color: Color(0xFF9AA8BC),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '+ CHF ${analytics.monthlyNet.toStringAsFixed(0)} available after spending this month',
              style: const TextStyle(
                color: finoraInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowMetric extends StatelessWidget {
  const _CashFlowMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: finoraInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringPaymentsCard extends StatelessWidget {
  const _RecurringPaymentsCard({
    required this.analytics,
    required this.showAll,
  });
  final AccountAnalytics analytics;
  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final payments = showAll
        ? analytics.recurringPayments
        : analytics.recurringPayments.take(3).toList();
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${analytics.recurringPayments.length} detected',
                    style: const TextStyle(
                      color: finoraInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'CHF ${analytics.recurringTotal.toStringAsFixed(2)} / month',
                  style: const TextStyle(
                    color: finoraPink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < payments.length; index++) ...[
            _RecurringPaymentTile(payment: payments[index]),
            if (index != payments.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _RecurringPaymentTile extends StatelessWidget {
  const _RecurringPaymentTile({required this.payment});
  final RecurringPayment payment;

  @override
  Widget build(BuildContext context) {
    final icon = switch (payment.category) {
      'Health insurance' ||
      'Household insurance' => Icons.health_and_safety_outlined,
      'Phone & internet' => Icons.wifi,
      'Membership' => Icons.fitness_center,
      _ => Icons.subscriptions_outlined,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: finoraSoftBlue,
        foregroundColor: finoraBlue,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        payment.merchant,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${payment.category} · ${payment.nextDueLabel}',
        style: const TextStyle(color: Color(0xFF8A98AB), fontSize: 12),
      ),
      trailing: Text(
        'CHF ${payment.amount.amount.abs().toStringAsFixed(2)}',
        style: const TextStyle(color: finoraInk, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.icon,
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.value,
    required this.actionLabel,
    required this.onPressed,
  });
  final IconData icon;
  final Color accent;
  final String eyebrow;
  final String title;
  final String description;
  final String value;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: .12),
                  foregroundColor: accent,
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        style: const TextStyle(
                          color: finoraInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(color: Color(0xFF63718A), height: 1.35),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BalanceHistoryPainter extends CustomPainter {
  const _BalanceHistoryPainter({required this.points});
  final List<BalanceHistoryPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = points.map((point) => point.balance).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1, maxValue - minValue);
    const topPadding = 10.0;
    const bottomPadding = 8.0;
    final graphHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFE8EDF4)
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = topPadding + graphHeight * index / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = size.width * index / (points.length - 1);
      final normalized = (points[index].balance - minValue) / range;
      final y = topPadding + graphHeight * (1 - normalized);
      final offset = Offset(x, y);
      offsets.add(offset);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            finoraBlue.withValues(alpha: .22),
            finoraBlue.withValues(alpha: .01),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = finoraBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(offsets.last, 5, Paint()..color = finoraPink);
    canvas.drawCircle(offsets.last, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BalanceHistoryPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _CashFlowPainter extends CustomPainter {
  const _CashFlowPainter({required this.points});
  final List<CashFlowPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maximum = points
        .expand((point) => [point.income, point.spending])
        .reduce(math.max);
    final groupWidth = size.width / points.length;
    final barWidth = math.min(11.0, groupWidth * .22);
    final baseline = size.height;
    final background = Paint()..color = const Color(0xFFF0F3F8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      background,
    );

    for (var index = 0; index < points.length; index++) {
      final center = groupWidth * index + groupWidth / 2;
      final incomeHeight = size.height * points[index].income / maximum * .86;
      final spendingHeight =
          size.height * points[index].spending / maximum * .86;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center - barWidth - 2,
            baseline - incomeHeight,
            barWidth,
            incomeHeight,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = finoraGreen,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center + 2,
            baseline - spendingHeight,
            barWidth,
            spendingHeight,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = finoraPink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CashFlowPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}
