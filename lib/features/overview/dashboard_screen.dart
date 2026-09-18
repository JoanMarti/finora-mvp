import 'dart:math' as math;

import 'package:finora/app/theme.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/data/mock_market_data_repository.dart';
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
    final marketThemes = ref.watch(swissMarketThemesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(financialRepositoryProvider).refresh();
            ref.invalidate(overviewProvider);
            ref.invalidate(accountsProvider);
            ref.invalidate(transactionsProvider);
            ref.invalidate(swissMarketThemesProvider);
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
                const _WealthTrajectoryCard(),
                if (overviewValue != null) ...[
                  const SizedBox(height: 12),
                  _TotalBalanceBreakdownCard(overview: overviewValue),
                  const SizedBox(height: 24),
                  const SectionTitle('Grow your wealth'),
                  _WealthActionsCard(overview: overviewValue),
                ],
                const SizedBox(height: 24),
                const SectionTitle('Explore Swiss opportunities'),
                marketThemes.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, _) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Market themes are temporarily unavailable.'),
                    ),
                  ),
                  data: (themes) => _MarketThemesCard(themes: themes),
                ),
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
                'Your wealth at a glance',
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
                        'TOTAL WEALTH',
                        style: TextStyle(
                          color: finoraInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Cash · Investments · Retirement',
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
              'Net worth',
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

class _WealthTrajectoryCard extends StatelessWidget {
  const _WealthTrajectoryCard();

  static const _values = [
    109100.0,
    110450.0,
    111800.0,
    113200.0,
    114050.0,
    116480.4,
  ];

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
                          color: Color(0xFF8E9CAF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: finoraSoftBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '6 months',
                    style: TextStyle(
                      color: finoraBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+ CHF 7.4k',
                  style: TextStyle(
                    color: finoraInk,
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '+6.8%',
                  style: TextStyle(
                    color: finoraGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              'Net contributions and market performance',
              style: TextStyle(color: Color(0xFF8E9CAF), fontSize: 11),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 92,
              width: double.infinity,
              child: CustomPaint(
                painter: const _WealthTrendPainter(values: _values),
              ),
            ),
            const SizedBox(height: 6),
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

class _WealthTrendPainter extends CustomPainter {
  const _WealthTrendPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = maxValue - minValue;
    final chartRect = Rect.fromLTWH(0, 6, size.width, size.height - 12);

    final gridPaint = Paint()
      ..color = const Color(0xFFE8EDF4)
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
          colors: [Color(0x553A86FF), Color(0x003A86FF)],
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
    canvas.drawCircle(points.last, 3.2, Paint()..color = finoraPink);
  }

  @override
  bool shouldRepaint(covariant _WealthTrendPainter oldDelegate) =>
      oldDelegate.values != values;
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
                          Text(
                            overview.total.currency,
                            style: const TextStyle(
                              color: Color(0xFF9BA8B9),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${(overview.total.amount / 1000).toStringAsFixed(1)}k',
                            style: const TextStyle(
                              color: finoraInk,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1,
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

class _WealthActionsCard extends StatelessWidget {
  const _WealthActionsCard({required this.overview});

  final FinancialOverview overview;

  @override
  Widget build(BuildContext context) {
    final cashShare = overview.cash.amount / overview.total.amount;
    return Card(
      child: Column(
        children: [
          _WealthActionRow(
            icon: Icons.water_drop_outlined,
            color: finoraBlue,
            metric: '${(cashShare * 100).round()}% in cash',
            title: 'Define your liquidity target',
            description: 'Separate your emergency reserve from cash available for long-term goals.',
            onTap: () => context.go('/accounts'),
          ),
          const Divider(height: 1, indent: 72),
          _WealthActionRow(
            icon: Icons.savings_outlined,
            color: finoraAqua,
            metric: _compactMoney(overview.retirement),
            title: 'Build your Pillar 3a plan',
            description: 'Track annual contributions, fees and the investment mix behind retirement savings.',
            onTap: () => context.go('/accounts'),
          ),
          const Divider(height: 1, indent: 72),
          _WealthActionRow(
            icon: Icons.donut_large_outlined,
            color: finoraPink,
            metric: _compactMoney(overview.investments),
            title: 'Review diversification',
            description: 'Understand exposure by asset class, region and currency across every portfolio.',
            onTap: () => context.go('/accounts'),
          ),
        ],
      ),
    );
  }
}

class _WealthActionRow extends StatelessWidget {
  const _WealthActionRow({
    required this.icon,
    required this.color,
    required this.metric,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String metric;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: const TextStyle(
                      color: finoraInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF7E8CA0),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Icon(Icons.chevron_right, color: Color(0xFF9BA8B9)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketThemesCard extends StatelessWidget {
  const _MarketThemesCard({required this.themes});

  final List<MarketTheme> themes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < themes.length; index++) ...[
            _MarketThemeRow(
              theme: themes[index],
              onTap: () => _showMarketTheme(context, themes[index]),
            ),
            if (index < themes.length - 1) const Divider(height: 1, indent: 72),
          ],
        ],
      ),
    );
  }

  void _showMarketTheme(BuildContext context, MarketTheme theme) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                theme.title,
                style: const TextStyle(
                  color: finoraInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(theme.description),
              const SizedBox(height: 16),
              const Text(
                'A future comparison view can combine product costs, risk, holdings and licensed market data. This demo does not recommend or sell a product.',
                style: TextStyle(color: Color(0xFF7E8CA0), height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketThemeRow extends StatelessWidget {
  const _MarketThemeRow({required this.theme, required this.onTap});

  final MarketTheme theme;
  final VoidCallback onTap;

  IconData get icon => switch (theme.type) {
    MarketThemeType.equities => Icons.show_chart_rounded,
    MarketThemeType.bonds => Icons.account_balance_outlined,
    MarketThemeType.retirement => Icons.savings_outlined,
  };

  Color get color => switch (theme.type) {
    MarketThemeType.equities => finoraPink,
    MarketThemeType.bonds => finoraBlue,
    MarketThemeType.retirement => finoraAqua,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          theme.title,
                          style: const TextStyle(
                            color: finoraInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          theme.tag,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    theme.description,
                    style: const TextStyle(
                      color: Color(0xFF7E8CA0),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9BA8B9)),
          ],
        ),
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
              'Illustrative content, not investment advice. Live prices and product data are not connected yet; the data layer is ready for a licensed provider.',
              style: TextStyle(
                color: Color(0xFF5F7190),
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

String _compactMoney(Money money) =>
    '${money.currency} ${(money.amount / 1000).toStringAsFixed(1)}k';
