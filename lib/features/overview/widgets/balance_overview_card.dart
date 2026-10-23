import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';

class BalanceOverviewCard extends StatelessWidget {
  const BalanceOverviewCard({required this.overview, required this.onRefresh, super.key});

  final FinancialOverview overview;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final changeRate = overview.monthlyChangeRate;
    final hasDebt = !overview.liabilities.isZero;
    final l10n = context.l10n;
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
                        l10n.totalWealth.toUpperCase(),
                        style: const TextStyle(
                          color: finoraInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasDebt
                            ? l10n.wealthComponentsWithDebt
                            : l10n.wealthComponents,
                        style: const TextStyle(
                          color: finoraMutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: l10n.refreshAllConnections,
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
            Text(
              l10n.netWorth,
              style: const TextStyle(color: finoraMutedInk, fontSize: 13),
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
                    label: l10n.netWorthChangedThisMonth(
                      formatPercentChange(changeRate),
                    ),
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
                  label: l10n.allocationCash,
                  money: overview.cash,
                ),
                _BalancePart(
                  color: finoraInk,
                  label: l10n.allocationInvestments,
                  money: overview.investments,
                ),
                _BalancePart(
                  color: finoraSlate,
                  label: l10n.allocationPillar3a,
                  money: overview.retirement,
                ),
                if (hasDebt)
                  _BalancePart(
                    color: finoraDanger,
                    label: l10n.allocationDebt,
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
