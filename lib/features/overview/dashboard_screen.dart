import 'dart:math' as math;

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
    final overviewValue = overview.value;
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: ListView(
              children: [
                const _FinoraHeader(),
                const SizedBox(height: 18),
                overview.when(
                  loading: () => const SizedBox(
                    height: 218,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Your overview is temporarily unavailable.'),
                    ),
                  ),
                  data: (data) => _BalanceOverview(
                    overview: data,
                    onRefresh: () => ref.invalidate(overviewProvider),
                  ),
                ),
                const SizedBox(height: 12),
                const _CashFlowCard(),
                if (overviewValue != null) ...[
                  const SizedBox(height: 12),
                  _TotalBalanceBreakdownCard(overview: overviewValue),
                ],
                const SizedBox(height: 12),
                _InsightCard(onTap: () => context.go('/profile')),
                if (accounts != null && institutions != null) ...[
                  SectionTitle(
                    'Your institutions',
                    action: TextButton(
                      onPressed: () => context.go('/accounts'),
                      child: const Text('See all'),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < institutions.length;
                          index++
                        )
                          if (accounts.any(
                            (item) =>
                                item.institutionId == institutions[index].id,
                          )) ...[
                            _InstitutionRow(
                              institution: institutions[index],
                              accounts: accounts
                                  .where(
                                    (item) =>
                                        item.institutionId ==
                                        institutions[index].id,
                                  )
                                  .toList(),
                            ),
                            if (index < institutions.length - 1)
                              const Divider(height: 1, indent: 74),
                          ],
                      ],
                    ),
                  ),
                ],
                if (transactions != null) ...[
                  SectionTitle(
                    'Latest movements',
                    action: TextButton(
                      onPressed: () => context.go('/activity'),
                      child: const Text('See all'),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < transactions.take(3).length;
                          index++
                        ) ...[
                          TransactionTile(transaction: transactions[index]),
                          if (index < 2) const Divider(height: 1, indent: 72),
                        ],
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

class _FinoraHeader extends StatelessWidget {
  const _FinoraHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: finoraPink,
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33FF4F8F),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'finora',
                style: TextStyle(
                  color: finoraPink,
                  fontSize: 23,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Good morning, Joan',
                style: TextStyle(color: Color(0xFF8492A6), fontSize: 12),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none, color: finoraInk),
            ),
            Positioned(
              right: 7,
              top: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: finoraPink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const CircleAvatar(
          radius: 19,
          backgroundColor: finoraSoftBlue,
          foregroundColor: finoraInk,
          child: Text('JM', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({required this.overview, required this.onRefresh});

  final FinancialOverview overview;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        'GLOBAL OVERVIEW',
                        style: TextStyle(
                          color: finoraInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '4 institutions · Updated 4 min ago',
                        style: TextStyle(
                          color: Color(0xFF96A3B5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onRefresh,
                  style: IconButton.styleFrom(
                    backgroundColor: finoraSoftBlue,
                    foregroundColor: finoraBlue,
                  ),
                  icon: const Icon(Icons.sync, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Total balance',
              style: TextStyle(color: Color(0xFF8B99AC), fontSize: 13),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    formatMoney(overview.total),
                    style: const TextStyle(
                      color: finoraInk,
                      fontSize: 32,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: finoraMint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${overview.monthlyChange}%',
                    style: const TextStyle(
                      color: finoraGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                _BalancePart(
                  color: finoraBlue,
                  label: 'Cash',
                  money: overview.cash,
                ),
                _BalancePart(
                  color: finoraPink,
                  label: 'Investments',
                  money: overview.investments,
                ),
                _BalancePart(
                  color: finoraAqua,
                  label: 'Pillar 3a',
                  money: overview.retirement,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalancePart extends StatelessWidget {
  const _BalancePart({
    required this.color,
    required this.label,
    required this.money,
  });

  final Color color;
  final String label;
  final Money money;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF93A0B1),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _compactMoney(money),
                  style: const TextStyle(
                    color: finoraInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard();

  @override
  Widget build(BuildContext context) {
    const income = Money(6850);
    const spending = Money(967);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Income & spending',
                    style: TextStyle(
                      color: finoraInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'September  ›',
                  style: TextStyle(
                    color: finoraBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _FlowMetric(
                  label: 'INCOME',
                  value: formatMoney(income),
                  color: finoraBlue,
                ),
                Container(width: 1, height: 46, color: const Color(0xFFE4EAF2)),
                _FlowMetric(
                  label: 'SPENDING',
                  value: formatMoney(spending),
                  color: finoraPink,
                ),
                Container(width: 1, height: 46, color: const Color(0xFFE4EAF2)),
                const _FlowMetric(
                  label: 'NET',
                  value: '+ CHF 5.9k',
                  color: finoraGreen,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 62, child: _MiniBarChart()),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('APR', style: _monthStyle),
                Text('MAY', style: _monthStyle),
                Text('JUN', style: _monthStyle),
                Text('JUL', style: _monthStyle),
                Text('AUG', style: _monthStyle),
                Text('SEP', style: _activeMonthStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _monthStyle = TextStyle(
  color: Color(0xFF9BA8B9),
  fontSize: 10,
  fontWeight: FontWeight.w700,
);
const _activeMonthStyle = TextStyle(
  color: finoraPink,
  fontSize: 10,
  fontWeight: FontWeight.w800,
);

class _FlowMetric extends StatelessWidget {
  const _FlowMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: finoraInk,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart();

  @override
  Widget build(BuildContext context) {
    const income = [28.0, 42.0, 36.0, 50.0, 46.0, 58.0];
    const spending = [18.0, 30.0, 24.0, 33.0, 38.0, 25.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var index = 0; index < income.length; index++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      height: income[index],
                      decoration: BoxDecoration(
                        color: finoraBlue.withValues(alpha: .78),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: spending[index],
                      decoration: BoxDecoration(
                        color: index == income.length - 1
                            ? finoraPink
                            : finoraPink.withValues(alpha: .5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TotalBalanceBreakdownCard extends StatelessWidget {
  const _TotalBalanceBreakdownCard({required this.overview});

  final FinancialOverview overview;

  @override
  Widget build(BuildContext context) {
    final total = overview.total.amount;
    final cashShare = overview.cash.amount / total;
    final investmentShare = overview.investments.amount / total;
    final retirementShare = overview.retirement.amount / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total balance breakdown',
                  style: TextStyle(
                    color: finoraInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Unified across all your institutions',
                  style: TextStyle(color: Color(0xFF8E9CAF), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(112),
                        painter: _DonutPainter(
                          segments: [
                            (cashShare, finoraBlue),
                            (investmentShare, finoraPink),
                            (retirementShare, finoraAqua),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              color: Color(0xFF9BA8B9),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _compactMoney(overview.total),
                            style: const TextStyle(
                              color: finoraInk,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    children: [
                      _CategoryLine(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Cash',
                        value:
                            '${_compactMoney(overview.cash)} · ${(cashShare * 100).round()}%',
                        color: finoraBlue,
                      ),
                      const SizedBox(height: 14),
                      _CategoryLine(
                        icon: Icons.show_chart_rounded,
                        label: 'Investments',
                        value:
                            '${_compactMoney(overview.investments)} · ${(investmentShare * 100).round()}%',
                        color: finoraPink,
                      ),
                      const SizedBox(height: 14),
                      _CategoryLine(
                        icon: Icons.savings_outlined,
                        label: 'Pillar 3a',
                        value:
                            '${_compactMoney(overview.retirement)} · ${(retirementShare * 100).round()}%',
                        color: finoraAqua,
                      ),
                    ],
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

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: finoraInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: const TextStyle(color: Color(0xFF8E9CAF), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.segments});

  final List<(double, Color)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * .13;
    const gap = .045;
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = math.pi * 2 * segment.$1 - gap;
      canvas.drawArc(
        rect.deflate(stroke / 2),
        start,
        sweep,
        false,
        Paint()
          ..color = segment.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      start += math.pi * 2 * segment.$1;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFEDF3),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const Padding(
          padding: EdgeInsets.all(17),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: finoraPink,
                foregroundColor: Colors.white,
                child: Icon(Icons.notifications_active_outlined),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your ZKB connection needs attention',
                      style: TextStyle(
                        color: finoraInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Refresh access to keep balances up to date',
                      style: TextStyle(color: Color(0xFF7E8CA0), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: finoraPink),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstitutionRow extends StatelessWidget {
  const _InstitutionRow({required this.institution, required this.accounts});

  final Institution institution;
  final List<FinancialAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold<double>(
      0,
      (sum, item) => sum + item.balance.amount,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: InstitutionBadge(institution: institution, size: 44),
      title: Text(
        institution.name,
        style: const TextStyle(color: finoraInk, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${accounts.length} ${accounts.length == 1 ? 'account' : 'accounts'}',
        style: const TextStyle(color: Color(0xFF95A2B4), fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(Money(total)),
            style: const TextStyle(
              color: finoraInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.chevron_right, size: 19, color: finoraBlue),
        ],
      ),
      onTap: () => context.push('/institution/${institution.id}'),
    );
  }
}

String _compactMoney(Money money) =>
    '${money.currency} ${(money.amount / 1000).toStringAsFixed(1)}k';
