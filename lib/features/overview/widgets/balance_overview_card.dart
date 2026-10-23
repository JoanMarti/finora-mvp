import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';

class BalanceOverviewCard extends StatelessWidget {
  const BalanceOverviewCard({required this.overview, required this.onRefresh});

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
