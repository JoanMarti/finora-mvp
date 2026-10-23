import 'dart:math' as math;

import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/market_data_repository.dart';
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

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => refreshFinancialData(ref),
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
                  data: (data) => data.isEmpty
                      ? const _EmptyOverview()
                      : _BalanceOverview(
                          overview: data,
                          onRefresh: () => refreshFinancialData(ref),
                        ),
                ),
                if (overviewValue != null && !overviewValue.isEmpty) ...[
                  if (overviewValue.history.length >= 2) ...[
                    const SizedBox(height: 12),
                    _WealthTrajectoryCard(overview: overviewValue),
                  ],
                  const SizedBox(height: 24),
                  const SectionTitle('Your wealth plan'),
                  _WealthPlanCard(
                    overview: overviewValue,
                    targets: ref.watch(wealthTargetsProvider),
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle('Ideas for you'),
                  _PersonalizedInsightsCarousel(
                    insights: _buildInsights(
                      overviewValue,
                      ref.watch(wealthTargetsProvider),
                      ref.watch(marketThemesProvider).value ?? const [],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const _MarketDataNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinoraHeader extends ConsumerWidget {
  const _FinoraHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = ref.watch(sessionProvider).initials;
    final alerts = ref.watch(alertsProvider).value ?? const <FinoraAlert>[];
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: finoraBlue,
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(
                color: Color(0x333C94FF),
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
                  color: finoraBlue,
                  fontSize: 23,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your wealth at a glance',
                style: TextStyle(color: finoraMutedInk, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: alerts.isEmpty
              ? 'Notifications'
              : 'Notifications, ${alerts.length} new',
          onPressed: () => _showAlerts(context, alerts),
          icon: Badge(
            isLabelVisible: alerts.isNotEmpty,
            label: Text('${alerts.length}'),
            backgroundColor: finoraBlueText,
            child: const Icon(Icons.notifications_none, color: finoraInk),
          ),
        ),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.go('/profile'),
          child: CircleAvatar(
            radius: 19,
            backgroundColor: finoraSoftBlue,
            foregroundColor: finoraInk,
            child: Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

void _showAlerts(BuildContext context, List<FinoraAlert> alerts) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Notifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            if (alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "You're all caught up. Connections are healthy and no bills are due this week.",
                  style: TextStyle(color: finoraMutedInk, height: 1.4),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final alert in alerts)
                      ListTile(
                        leading: Icon(
                          switch (alert.severity) {
                            AlertSeverity.critical => Icons.error,
                            AlertSeverity.warning => Icons.schedule,
                            AlertSeverity.info => Icons.event_outlined,
                          },
                          color: switch (alert.severity) {
                            AlertSeverity.critical => finoraDanger,
                            AlertSeverity.warning => finoraWarning,
                            AlertSeverity.info => finoraBlueText,
                          },
                        ),
                        title: Text(
                          alert.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(alert.description),
                        trailing: alert.route == null
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: alert.route == null
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                context.push(alert.route!);
                              },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyOverview extends StatelessWidget {
  const _EmptyOverview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.link_off, color: finoraSlate, size: 32),
            const SizedBox(height: 12),
            const Text(
              'No accounts connected yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Connect a bank, investment or Pillar 3a provider to see your net worth here.',
              style: TextStyle(color: finoraMutedInk, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/connect'),
              icon: const Icon(Icons.add),
              label: const Text('Add an institution'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({required this.overview, required this.onRefresh});

  final FinancialOverview overview;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final changeRate = overview.monthlyChangeRate;
    final hasDebt = !overview.liabilities.isZero;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL WEALTH',
                        style: TextStyle(
                          color: finoraInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasDebt
                            ? 'Cash · Investments · Retirement · Debt'
                            : 'Cash · Investments · Retirement',
                        style: const TextStyle(
                          color: finoraMutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh all connections',
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
              'Net worth',
              style: TextStyle(color: finoraMutedInk, fontSize: 13),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
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
                ),
                if (changeRate != null)
                  Semantics(
                    label:
                        'Net worth changed ${formatPercentChange(changeRate)} this month',
                    child: ExcludeSemantics(
                      child: ValuePill(
                        label: formatPercentChange(changeRate),
                        color: changeRate < 0 ? finoraDanger : finoraGreen,
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
                  color: finoraInk,
                  label: 'Investments',
                  money: overview.investments,
                ),
                _BalancePart(
                  color: finoraSlate,
                  label: 'Pillar 3a',
                  money: overview.retirement,
                ),
                if (hasDebt)
                  _BalancePart(
                    color: finoraDanger,
                    label: 'Debt',
                    money: -overview.liabilities,
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
      child: Semantics(
        label: '$label ${formatMoney(money)}',
        child: ExcludeSemantics(
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
                        color: finoraMutedInk,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatCompactMoney(money),
                        style: const TextStyle(
                          color: finoraInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WealthTrajectoryCard extends StatelessWidget {
  const _WealthTrajectoryCard({required this.overview});

  final FinancialOverview overview;

  @override
  Widget build(BuildContext context) {
    final history = overview.history;
    final change = overview.periodChange;
    final changeRate = overview.periodChangeRate;
    final values = [for (final point in history) point.balance.amount];
    final positive = !change.isNegative;
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
                        'Wealth evolution',
                        style: TextStyle(
                          color: finoraInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your unified net worth over time',
                        style: TextStyle(
                          color: finoraMutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ValuePill(
                  label: '${history.length} months',
                  color: finoraBlue,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCompactMoney(change, signed: true),
                  style: const TextStyle(
                    color: finoraInk,
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (changeRate != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatPercentChange(changeRate),
                    style: TextStyle(
                      color: positive ? finoraGreen : finoraDanger,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              'Net contributions and market performance',
              style: TextStyle(color: finoraMutedInk, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Semantics(
              label:
                  'Net worth ${positive ? 'grew' : 'fell'} by ${formatMoney(change.abs())} over ${history.length} months, '
                  'ending at ${formatMoney(history.last.balance)}.',
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 92,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _WealthTrendPainter(values: values),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final point in history)
                  Text(
                    formatMonthShort(point.month),
                    style: point == history.last
                        ? _activeMonthStyle
                        : _monthStyle,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _monthStyle = TextStyle(
  color: finoraMutedInk,
  fontSize: 10,
  fontWeight: FontWeight.w700,
);
const _activeMonthStyle = TextStyle(
  color: finoraBlueText,
  fontSize: 10,
  fontWeight: FontWeight.w800,
);

class _WealthTrendPainter extends CustomPainter {
  const _WealthTrendPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1.0, maxValue - minValue);
    final chartRect = Rect.fromLTWH(0, 6, size.width, size.height - 12);

    final gridPaint = Paint()
      ..color = finoraBorder
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = chartRect.top + chartRect.height * index / 2;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final points = <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          chartRect.left + chartRect.width * index / (values.length - 1),
          chartRect.bottom -
              ((values[index] - minValue) / range) * chartRect.height,
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      line.lineTo(points[index].dx, points[index].dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, chartRect.bottom)
      ..lineTo(points.first.dx, chartRect.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x553C94FF), Color(0x003C94FF)],
        ).createShader(chartRect),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = finoraBlue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(points.last, 5, Paint()..color = Colors.white);
    canvas.drawCircle(points.last, 3.2, Paint()..color = finoraBlue);
  }

  @override
  bool shouldRepaint(covariant _WealthTrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _PlanRowData {
  const _PlanRowData({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });
  final String label;
  final String value;
  final double progress;
  final Color color;
}

/// Turns the overview and targets into the three plan rows. Kept separate
/// from the widget so the maths is easy to read and test.
List<_PlanRowData> _planRows(FinancialOverview overview, WealthTargets targets) {
  // Safety buffer: savings vs. N months of everyday spending.
  final bufferTarget = overview.monthlySpending.isZero
      ? const Money.cents(2000000)
      : overview.monthlySpending * targets.safetyBufferMonths;
  final bufferProgress = bufferTarget.isZero
      ? 0.0
      : (overview.savings.cents / bufferTarget.cents).clamp(0.0, 1.0).toDouble();

  // Long-term allocation: investments + Pillar 3a vs. target share.
  final longTermShare = overview.share(overview.investments + overview.retirement);
  final longTermProgress = (longTermShare / targets.longTermShare)
      .clamp(0.0, 1.0)
      .toDouble();

  // Pillar 3a: contributions this year vs. the legal maximum.
  final contributed = overview.pillar3aContributionsThisYear;
  final hasPillar3a = !overview.retirement.isZero;
  final pillarProgress = hasPillar3a
      ? (contributed.cents / targets.pillar3aAnnualLimit.cents)
            .clamp(0.0, 1.0)
            .toDouble()
      : 0.0;

  return [
    _PlanRowData(
      label: 'Safety buffer',
      value:
          '${formatCompactMoney(overview.savings)} of ${formatCompactMoney(bufferTarget)}',
      progress: bufferProgress,
      color: finoraBlue,
    ),
    _PlanRowData(
      label: 'Long-term allocation',
      value:
          '${(longTermShare * 100).round()}% of ${(targets.longTermShare * 100).round()}% target',
      progress: longTermProgress,
      color: finoraInk,
    ),
    _PlanRowData(
      label: 'Pillar 3a this year',
      value: hasPillar3a
          ? '${formatCompactMoney(contributed)} of ${formatCompactMoney(targets.pillar3aAnnualLimit)}'
          : 'No Pillar 3a connected',
      progress: pillarProgress,
      color: finoraSlate,
    ),
  ];
}

class _WealthPlanCard extends StatelessWidget {
  const _WealthPlanCard({required this.overview, required this.targets});

  final FinancialOverview overview;
  final WealthTargets targets;

  @override
  Widget build(BuildContext context) {
    final rows = _planRows(overview, targets);
    final onTrack = rows.every((row) => row.progress >= .75);
    final statusColor = onTrack ? finoraGreen : finoraWarning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Are you on track?',
                        style: TextStyle(
                          color: finoraInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Progress against your personal targets',
                        style: TextStyle(
                          color: finoraMutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        onTrack ? Icons.check_circle : Icons.flag_outlined,
                        color: statusColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        onTrack ? 'On track' : 'Needs attention',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (var index = 0; index < rows.length; index++) ...[
              _PlanProgressRow(data: rows[index]),
              if (index != rows.length - 1) const SizedBox(height: 17),
            ],
            const SizedBox(height: 18),
            Text(
              'Buffer target: ${targets.safetyBufferMonths} months of spending. '
              'Pillar 3a limit for employees with a pension fund. '
              'Personal targets are coming in a later step.',
              style: const TextStyle(
                color: finoraMutedInk,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanProgressRow extends StatelessWidget {
  const _PlanProgressRow({required this.data});

  final _PlanRowData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${data.label}: ${data.value}, ${(data.progress * 100).round()} percent',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.label,
                    style: const TextStyle(
                      color: finoraInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: finoraMutedInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: data.progress,
                minHeight: 7,
                backgroundColor: data.color.withValues(alpha: .12),
                valueColor: AlwaysStoppedAnimation(data.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalInsight {
  const _PersonalInsight({
    required this.icon,
    required this.color,
    required this.eyebrow,
    required this.metric,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String eyebrow;
  final String metric;
  final String title;
  final String description;
}

/// Ideas generated from the user's own numbers, followed by educational
/// market themes from [MarketDataRepository].
List<_PersonalInsight> _buildInsights(
  FinancialOverview overview,
  WealthTargets targets,
  List<MarketTheme> themes,
) {
  final cashShare = overview.share(overview.cash);
  final allocations = {
    'Cash': overview.cash,
    'Investments': overview.investments,
    'Pillar 3a': overview.retirement,
  };
  final largest = allocations.entries.reduce(
    (a, b) => a.value.compareTo(b.value) >= 0 ? a : b,
  );
  final changeRate = overview.monthlyChangeRate;
  final pillarRoom =
      targets.pillar3aAnnualLimit - overview.pillar3aContributionsThisYear;

  return [
    _PersonalInsight(
      icon: Icons.water_drop_outlined,
      color: finoraBlue,
      eyebrow: 'ALLOCATION',
      metric:
          '${formatCompactMoney(largest.value)} · ${(overview.share(largest.value) * 100).round()}%',
      title: '${largest.key} is your largest allocation',
      description: largest.key == 'Cash'
          ? 'Set a personal liquidity target before deciding what could support longer-term goals.'
          : 'Check that your cash buffer still covers unexpected costs before adding more.',
    ),
    if (changeRate != null)
      _PersonalInsight(
        icon: changeRate < 0
            ? Icons.trending_down_rounded
            : Icons.trending_up_rounded,
        color: changeRate < 0 ? finoraWarning : finoraGreen,
        eyebrow: 'MOMENTUM',
        metric: '${formatPercentChange(changeRate)} this month',
        title: changeRate < 0
            ? 'Your wealth dipped this month'
            : 'Your wealth is moving upward',
        description:
            'Compare new contributions with market performance before changing your strategy.',
      ),
    if (!overview.retirement.isZero)
      _PersonalInsight(
        icon: Icons.savings_outlined,
        color: finoraSlate,
        eyebrow: 'RETIREMENT',
        metric: pillarRoom.cents > 0
            ? '${formatCompactMoney(pillarRoom)} left this year'
            : 'Annual limit reached',
        title: pillarRoom.cents > 0
            ? 'Room left in your Pillar 3a'
            : 'Pillar 3a maxed out this year',
        description: pillarRoom.cents > 0
            ? 'Contributions up to the annual limit reduce taxable income if they are booked before the year ends.'
            : 'Keep contributions, fees and equity allocation visible across every 3a provider.',
      ),
    if (!overview.liabilities.isZero)
      _PersonalInsight(
        icon: Icons.credit_card_outlined,
        color: finoraDanger,
        eyebrow: 'DEBT',
        metric: '${formatCompactMoney(overview.liabilities)} outstanding',
        title: 'Keep debt next to your savings',
        description:
            'Seeing balances and rates together makes it easier to decide what to repay first.',
      ),
    for (final theme in themes)
      _PersonalInsight(
        icon: switch (theme.type) {
          MarketThemeType.bonds => Icons.account_balance_outlined,
          MarketThemeType.equities => Icons.show_chart_rounded,
          MarketThemeType.retirement => Icons.nature_people_outlined,
        },
        color: switch (theme.type) {
          MarketThemeType.bonds => finoraSilver,
          MarketThemeType.equities => finoraBlue,
          MarketThemeType.retirement => finoraSlate,
        },
        eyebrow: theme.tag,
        metric: switch (theme.type) {
          MarketThemeType.bonds =>
            'Because cash represents ${(cashShare * 100).round()}%',
          MarketThemeType.equities => 'Long-term allocation idea',
          MarketThemeType.retirement => 'Across every 3a provider',
        },
        title: theme.title,
        description: theme.description,
      ),
  ];
}

class _PersonalizedInsightsCarousel extends StatefulWidget {
  const _PersonalizedInsightsCarousel({required this.insights});

  final List<_PersonalInsight> insights;

  @override
  State<_PersonalizedInsightsCarousel> createState() =>
      _PersonalizedInsightsCarouselState();
}

class _PersonalizedInsightsCarouselState
    extends State<_PersonalizedInsightsCarousel> {
  late final PageController _controller;
  var _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .93);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insights = widget.insights;
    final current = math.min(_currentPage, math.max(0, insights.length - 1));

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: insights.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                right: index == insights.length - 1 ? 0 : 10,
              ),
              child: _PersonalInsightCard(insight: insights[index]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Idea ${current + 1} of ${insights.length}',
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < insights.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: index == current ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == current ? finoraBlue : finoraSilver,
                      borderRadius: BorderRadius.circular(10),
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

class _PersonalInsightCard extends StatelessWidget {
  const _PersonalInsightCard({required this.insight});

  final _PersonalInsight insight;

  @override
  Widget build(BuildContext context) {
    final textColor = finoraAccessibleAccent(insight.color);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [insight.color.withValues(alpha: .13), Colors.white],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: insight.color.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: insight.color.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
                child: Icon(insight.icon, color: textColor, size: 19),
              ),
              const SizedBox(width: 10),
              Text(
                insight.eyebrow,
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.metric,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            insight.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: finoraInk,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              insight.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: finoraMutedInk,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketDataNote extends StatelessWidget {
  const _MarketDataNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: finoraSoftBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: finoraBlue, size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Illustrative targets and ideas, not investment advice. Live prices and product data are not connected yet.',
              style: TextStyle(
                color: finoraMutedInk,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
