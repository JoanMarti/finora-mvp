import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';

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

class WealthPlanCard extends StatelessWidget {
  const WealthPlanCard({required this.overview, required this.targets});

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
