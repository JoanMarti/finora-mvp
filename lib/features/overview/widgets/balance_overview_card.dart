import 'dart:math' as math;

import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';

/// Hero card with the net worth, its trend and what it is made of.
class BalanceOverviewCard extends StatelessWidget {
  const BalanceOverviewCard({
    required this.overview,
    required this.onRefresh,
    super.key,
  });

  final FinancialOverview overview;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final changeRate = overview.monthlyChangeRate;
    final l10n = context.l10n;
    final parts = [
      (l10n.allocationCash, overview.cash),
      (l10n.allocationInvestments, overview.investments),
      (l10n.allocationPillar3a, overview.retirement),
      if (!overview.otherAssets.isZero)
        (l10n.allocationOther, overview.otherAssets),
      if (!overview.liabilities.isZero)
        (l10n.allocationDebt, -overview.liabilities),
    ];
    final up = (changeRate ?? 0) >= 0;
    return HeroCard(
      gradient: finoraBrandGradient,
      child: Stack(
        children: [
          // Soft decorative glow in the corner.
          Positioned(
            right: -60,
            top: -70,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1AFFFFFF),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.totalWealth.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.refreshAllConnections,
                      onPressed: onRefresh,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x26FFFFFF),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.sync, size: 20),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatMoney(overview.total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              fontFeatures: finoraTabular,
                            ),
                          ),
                        ),
                      ),
                      if (changeRate != null) ...[
                        const SizedBox(width: 8),
                        Semantics(
                          label: l10n.netWorthChangedThisMonth(
                            formatPercentChange(changeRate),
                          ),
                          child: ExcludeSemantics(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    up
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 14,
                                    color: up ? finoraGreen : finoraDanger,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    formatPercentChange(changeRate),
                                    style: TextStyle(
                                      color: up ? finoraGreen : finoraDanger,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.netWorth,
                  style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 13),
                ),
                if (overview.history.length >= 2) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _SparklinePainter([
                            for (final point in overview.history)
                              point.balance.amount,
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // One scrollable row keeps the card compact whatever the
                // number of parts.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (label, money) in parts)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child:
                        Semantics(
                          label: '$label ${formatMoney(money)}',
                          child: ExcludeSemantics(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x1FFFFFFF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      color: Color(0xB3FFFFFF),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    formatCompactMoney(money),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: finoraTabular,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ),
                    ],
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

/// Smooth white trend line with a fading fill, drawn on the hero card.
class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1.0, maxValue - minValue);
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * i / (values.length - 1),
          size.height - 4 - (values[i] - minValue) / range * (size.height - 8),
        ),
    ];
    final line = smoothPath(points);
    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        line,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(points.last, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}

/// A curve through [points] using midpoint quadratic segments, so trend
/// lines read as smooth rather than jagged.
Path smoothPath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  if (points.length == 2) return path..lineTo(points.last.dx, points.last.dy);
  for (var i = 1; i < points.length - 1; i++) {
    final mid = Offset(
      (points[i].dx + points[i + 1].dx) / 2,
      (points[i].dy + points[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  return path..lineTo(points.last.dx, points.last.dy);
}
