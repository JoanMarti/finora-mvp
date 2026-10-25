import 'dart:math' as math;

import 'package:finora/app/theme.dart';
import 'package:finora/domain/market_data_repository.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
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
  AppLocalizations l10n,
  FinancialOverview overview,
  WealthTargets targets,
  List<MarketTheme> themes,
) {
  final cashShare = overview.share(overview.cash);
  final allocations = {
    l10n.allocationCash: overview.cash,
    l10n.allocationInvestments: overview.investments,
    l10n.allocationPillar3a: overview.retirement,
  };
  final largest = allocations.entries.reduce(
    (a, b) => a.value.compareTo(b.value) >= 0 ? a : b,
  );
  final cashIsLargest = identical(largest.value, overview.cash);
  final changeRate = overview.monthlyChangeRate;
  final pillarRoom =
      targets.pillar3aAnnualLimit - overview.pillar3aContributionsThisYear;
  final hasPillarRoom = pillarRoom.cents > 0;

  return [
    PersonalInsight(
      icon: Icons.water_drop_outlined,
      color: finoraBlue,
      eyebrow: l10n.insightAllocationEyebrow,
      metric:
          '${formatCompactMoney(largest.value)} · ${(overview.share(largest.value) * 100).round()}%',
      title: l10n.insightLargestAllocation(largest.key),
      description: cashIsLargest
          ? l10n.insightCashLargestBody
          : l10n.insightOtherLargestBody,
    ),
    if (changeRate != null)
      PersonalInsight(
        icon: changeRate < 0
            ? Icons.trending_down_rounded
            : Icons.trending_up_rounded,
        color: changeRate < 0 ? finoraWarning : finoraGreen,
        eyebrow: l10n.insightMomentumEyebrow,
        metric: l10n.insightChangeThisMonth(formatPercentChange(changeRate)),
        title: changeRate < 0
            ? l10n.insightWealthDipped
            : l10n.insightWealthUp,
        description: l10n.insightMomentumBody,
      ),
    if (!overview.retirement.isZero)
      PersonalInsight(
        icon: Icons.savings_outlined,
        color: finoraSlate,
        eyebrow: l10n.insightRetirementEyebrow,
        metric: hasPillarRoom
            ? l10n.insightPillarRoomMetric(formatCompactMoney(pillarRoom))
            : l10n.insightPillarLimitReached,
        title: hasPillarRoom
            ? l10n.insightPillarRoomTitle
            : l10n.insightPillarMaxedTitle,
        description: hasPillarRoom
            ? l10n.insightPillarRoomBody
            : l10n.insightPillarMaxedBody,
      ),
    if (!overview.liabilities.isZero)
      PersonalInsight(
        icon: Icons.credit_card_outlined,
        color: finoraDanger,
        eyebrow: l10n.insightDebtEyebrow,
        metric: l10n.insightDebtMetric(
          formatCompactMoney(overview.liabilities),
        ),
        title: l10n.insightDebtTitle,
        description: l10n.insightDebtBody,
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
          MarketThemeType.bonds => l10n.themeBondsMetric(
            (cashShare * 100).round(),
          ),
          MarketThemeType.equities => l10n.themeEquitiesMetric,
          MarketThemeType.retirement => l10n.themeRetirementMetric,
        },
        title: theme.title,
        description: theme.description,
      ),
  ];
}

class PersonalizedInsightsCarousel extends StatefulWidget {
  const PersonalizedInsightsCarousel({required this.insights, super.key});

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
          label: context.l10n.ideaPosition(current + 1, insights.length),
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
        borderRadius: BorderRadius.circular(finoraRadius),
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
  const MarketDataNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: finoraSoftBlue,
        borderRadius: BorderRadius.circular(finoraRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: finoraBlue, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.marketDataNote,
              style: const TextStyle(
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
