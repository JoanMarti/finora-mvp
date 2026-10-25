import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/l10n/l10n.dart';
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
List<_PlanRowData> _planRows(
  AppLocalizations l10n,
  FinancialOverview overview,
  WealthTargets targets,
) {
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
      label: l10n.planSafetyBuffer,
      value: l10n.planProgressOf(
        formatCompactMoney(overview.savings),
        formatCompactMoney(bufferTarget),
      ),
      progress: bufferProgress,
      color: finoraBlue,
    ),
    _PlanRowData(
      label: l10n.planLongTerm,
      value: l10n.planShareOfTarget(
        (longTermShare * 100).round(),
        (targets.longTermShare * 100).round(),
      ),
      progress: longTermProgress,
      color: finoraInk,
    ),
    _PlanRowData(
      label: l10n.planPillar3aYear,
      value: hasPillar3a
          ? l10n.planProgressOf(
              formatCompactMoney(contributed),
              formatCompactMoney(targets.pillar3aAnnualLimit),
            )
          : l10n.planNoPillar3a,
      progress: pillarProgress,
      color: finoraSlate,
    ),
  ];
}

class WealthPlanCard extends StatelessWidget {
  const WealthPlanCard({
    required this.overview,
    required this.targets,
    this.goals = const [],
    super.key,
  });

  final FinancialOverview overview;
  final WealthTargets targets;

  /// Personal goals, shown under the plan rows.
  final List<GoalProgress> goals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = _planRows(l10n, overview, targets);
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.planTitle,
                        style: const TextStyle(
                          color: finoraInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.planSubtitle,
                        style: const TextStyle(
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
                        onTrack ? l10n.planOnTrack : l10n.planNeedsAttention,
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
            if (goals.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              for (var index = 0; index < goals.length; index++) ...[
                _PlanProgressRow(
                  data: _PlanRowData(
                    label: goals[index].goal.name,
                    value: l10n.planProgressOf(
                      formatCompactMoney(goals[index].saved),
                      formatCompactMoney(goals[index].goal.target),
                    ),
                    progress: goals[index].progress,
                    color: finoraGreen,
                  ),
                ),
                if (index != goals.length - 1) const SizedBox(height: 17),
              ],
            ],
            const SizedBox(height: 18),
            Text(
              l10n.planFootnote(targets.safetyBufferMonths),
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
      label: context.l10n.planRowSemantics(
        data.label,
        data.value,
        (data.progress * 100).round(),
      ),
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
