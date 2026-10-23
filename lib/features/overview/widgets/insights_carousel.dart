import 'dart:math' as math;

import 'package:finora/app/theme.dart';
import 'package:finora/domain/market_data_repository.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';

class PersonalInsight {
  const PersonalInsight({
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
List<PersonalInsight> buildInsights(
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
    PersonalInsight(
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
      PersonalInsight(
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
      PersonalInsight(
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
      PersonalInsight(
        icon: Icons.credit_card_outlined,
        color: finoraDanger,
        eyebrow: 'DEBT',
        metric: '${formatCompactMoney(overview.liabilities)} outstanding',
        title: 'Keep debt next to your savings',
        description:
            'Seeing balances and rates together makes it easier to decide what to repay first.',
      ),
    for (final theme in themes)
      PersonalInsight(
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

class PersonalizedInsightsCarousel extends StatefulWidget {
  const PersonalizedInsightsCarousel({required this.insights});

  final List<PersonalInsight> insights;

  @override
  State<PersonalizedInsightsCarousel> createState() =>
      _PersonalizedInsightsCarouselState();
}

class _PersonalizedInsightsCarouselState
    extends State<PersonalizedInsightsCarousel> {
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

  final PersonalInsight insight;

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

class MarketDataNote extends StatelessWidget {
  const MarketDataNote();

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
