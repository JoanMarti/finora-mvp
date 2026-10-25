import 'dart:math' as math;

import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';

class WealthTrajectoryCard extends StatelessWidget {
  const WealthTrajectoryCard({required this.overview, super.key});

  final FinancialOverview overview;

  @override
  Widget build(BuildContext context) {
    final history = overview.history;
    final change = overview.periodChange;
    final changeRate = overview.periodChangeRate;
    final values = [for (final point in history) point.balance.amount];
    final positive = !change.isNegative;
    final l10n = context.l10n;
    final period = l10n.monthsCount(history.length);
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
                      Text(
                        l10n.wealthEvolution,
                        style: const TextStyle(
                          color: finoraInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.wealthEvolutionSubtitle,
                        style: const TextStyle(
                          color: finoraMutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ValuePill(
                  label: period,
                  color: finoraBlue,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatCompactMoney(change, signed: true),
                      style: const TextStyle(
                        color: finoraInk,
                        fontSize: 23,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
            Text(
              l10n.contributionsAndPerformance,
              style: const TextStyle(color: finoraMutedInk, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: (positive ? l10n.netWorthTrendGrew : l10n.netWorthTrendFell)(
                formatMoney(change.abs()),
                period,
                formatMoney(history.last.balance),
              ),
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
