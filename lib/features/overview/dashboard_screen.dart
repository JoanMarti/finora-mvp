import 'dart:math' as math;

import 'package:finora/app/theme.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    final overviewValue = overview.value;

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
                const _WealthTrajectoryCard(),
                if (overviewValue != null) ...[
                  const SizedBox(height: 24),
                  const SectionTitle('Your wealth plan'),
                  _WealthPlanCard(overview: overviewValue),
                  const SizedBox(height: 24),
                  const SectionTitle('Ideas for you'),
                  _PersonalizedInsightsCarousel(overview: overviewValue),
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

class _WealthPlanCard extends StatelessWidget {
  const _WealthPlanCard({required this.overview});

  final FinancialOverview overview;

  @override
  Widget build(BuildContext context) {
    final investedShare = overview.investments.amount / overview.total.amount;
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
                          color: Color(0xFF8E9CAF),
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
                    color: finoraMint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: finoraGreen, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'On track',
                        style: TextStyle(
                          color: finoraGreen,
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
            const _PlanProgressRow(
              label: 'Safety buffer',
              value: 'CHF 20k of CHF 24k',
              progress: .83,
              color: finoraBlue,
            ),
            const SizedBox(height: 17),
            _PlanProgressRow(
              label: 'Long-term allocation',
              value: '${(investedShare * 100).round()}% of 45% target',
              progress: (investedShare / .45).clamp(0, 1),
              color: finoraPink,
            ),
            const SizedBox(height: 17),
            const _PlanProgressRow(
              label: 'Pillar 3a yearly plan',
              value: '72% funded',
              progress: .72,
              color: finoraAqua,
            ),
            const SizedBox(height: 18),
            const Text(
              'Targets are illustrative in this MVP and can be personalized in the next step.',
              style: TextStyle(
                color: Color(0xFF8E9CAF),
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
  const _PlanProgressRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: finoraInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF6F7E93),
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
            value: progress,
            minHeight: 7,
            backgroundColor: color.withValues(alpha: .12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _PersonalizedInsightsCarousel extends StatefulWidget {
  const _PersonalizedInsightsCarousel({required this.overview});

  final FinancialOverview overview;

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
    final overview = widget.overview;
    final cashShare = overview.cash.amount / overview.total.amount;
    final retirementShare = overview.retirement.amount / overview.total.amount;
    final insights = <_PersonalInsight>[
      _PersonalInsight(
        icon: Icons.water_drop_outlined,
        color: finoraBlue,
        eyebrow: 'LIQUIDITY',
        metric:
            '${_compactMoney(overview.cash)} · ${(cashShare * 100).round()}%',
        title: 'Cash is your largest allocation',
        description: 'Set a personal liquidity target before deciding what could support longer-term goals.',
      ),
      _PersonalInsight(
        icon: Icons.trending_up_rounded,
        color: finoraGreen,
        eyebrow: 'MOMENTUM',
        metric: '+${overview.monthlyChange}% this month',
        title: 'Your wealth is moving upward',
        description: 'Compare new contributions with market performance before changing your strategy.',
      ),
      _PersonalInsight(
        icon: Icons.savings_outlined,
        color: finoraAqua,
        eyebrow: 'RETIREMENT',
        metric:
            '${_compactMoney(overview.retirement)} · ${(retirementShare * 100).round()}%',
        title: 'Make Pillar 3a progress visible',
        description: 'Keep contributions, fees and equity allocation visible across every 3a provider.',
      ),
      _PersonalInsight(
        icon: Icons.account_balance_outlined,
        color: finoraYellow,
        eyebrow: 'LEARN',
        metric: 'Because cash represents ${(cashShare * 100).round()}%',
        title: 'Understand CHF bond funds',
        description: 'Learn how duration, credit quality and fees affect lower-volatility CHF investments.',
      ),
      const _PersonalInsight(
        icon: Icons.show_chart_rounded,
        color: finoraPink,
        eyebrow: 'EXPLORE',
        metric: 'Long-term allocation idea',
        title: 'Compare broad Swiss equity ETFs',
        description: 'Explore costs, index coverage and concentration before considering any product.',
      ),
    ];

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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < insights.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: index == _currentPage ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _currentPage
                      ? finoraPink
                      : const Color(0xFFD3DBE6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
          ],
        ),
      ],
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

class _PersonalInsightCard extends StatelessWidget {
  const _PersonalInsightCard({required this.insight});

  final _PersonalInsight insight;

  @override
  Widget build(BuildContext context) {
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
                child: Icon(insight.icon, color: insight.color, size: 19),
              ),
              const SizedBox(width: 10),
              Text(
                insight.eyebrow,
                style: TextStyle(
                  color: insight.color,
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
              color: insight.color,
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
                color: Color(0xFF6F7E93),
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
