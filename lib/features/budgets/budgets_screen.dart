import 'package:finora/app/theme.dart';
import 'package:finora/application/budgets.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/budgets.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Color budgetColor(BudgetStatus status) => switch (status) {
  BudgetStatus.onTrack => finoraGreen,
  BudgetStatus.nearLimit => finoraWarning,
  BudgetStatus.over => finoraDanger,
};

/// Monthly limits per spending category.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(budgetSummaryProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.budgetsTitle),
      ),
      body: FinoraPage(
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.overviewUnavailable)),
          data: (data) => ListView(
            children: [
              if (data.isEmpty)
                _EmptyBudgets(onSuggest: () => _suggest(ref))
              else ...[
                _SummaryCard(summary: data),
                SectionTitle(l10n.budgetsCategoriesSection),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < data.lines.length; i++) ...[
                        _BudgetTile(line: data.lines[i]),
                        if (i != data.lines.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              ],
              if (data.unbudgeted.isNotEmpty) ...[
                SectionTitle(l10n.budgetsWithoutSection),
                Card(
                  child: Column(
                    children: [
                      for (final item in data.unbudgeted)
                        ListTile(
                          title: Text(l10n.transactionCategory(item.category)),
                          subtitle: Text(
                            l10n.budgetsSpentThisMonth(formatMoney(item.amount.abs())),
                          ),
                          trailing: const Icon(Icons.add),
                          onTap: () => showBudgetEditor(
                            context,
                            item.category,
                            null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.budgetsNote,
                style: const TextStyle(color: finoraMutedInk, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _suggest(WidgetRef ref) async {
    final analysis = await ref.read(spendingAnalysisProvider.future);
    ref
        .read(sessionProvider.notifier)
        .setBudgets(
          BudgetSummary.suggest(analysis.combined.spendingCategories),
        );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets({required this.onSuggest});
  final VoidCallback onSuggest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.pie_chart_outline, color: finoraBlueText, size: 32),
            const SizedBox(height: 10),
            Text(
              l10n.budgetsEmptyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.budgetsEmptyBody,
              style: const TextStyle(color: finoraMutedInk, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSuggest,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(l10n.budgetsSuggest),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final share = summary.totalLimit.isZero
        ? 0.0
        : summary.totalSpent.cents / summary.totalLimit.cents;
    final over = summary.totalRemaining.isNegative;
    return Card(
      color: finoraInk,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              over ? l10n.budgetsOverTotal : l10n.budgetsLeftThisMonth,
              style: const TextStyle(color: finoraSilver),
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(summary.totalRemaining.abs()),
              style: TextStyle(
                color: over ? const Color(0xFFFFB4AB) : Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.white24,
                color: over ? const Color(0xFFFFB4AB) : const Color(0xFF8ED8B9),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.budgetsSpentOf(
                formatMoney(summary.totalSpent),
                formatMoney(summary.totalLimit),
              ),
              style: const TextStyle(color: finoraSilver, fontSize: 12),
            ),
            if (!over)
              Text(
                l10n.budgetsSafePerDay(
                  formatMoney(summary.safePerDay),
                  summary.daysLeft,
                ),
                style: const TextStyle(color: finoraSilver, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.line});
  final BudgetLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = budgetColor(line.status);
    return InkWell(
      onTap: () => showBudgetEditor(context, line.category, line.limit),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.transactionCategory(line.category),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${formatMoneyWhole(line.spent)} / ${formatMoneyWhole(line.limit)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: line.share.clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                backgroundColor: finoraSoftBlue,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              line.status == BudgetStatus.over
                  ? l10n.budgetsOverBy(formatMoney(line.remaining.abs()))
                  : l10n.budgetsLeft(formatMoney(line.remaining)),
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sets or removes the monthly limit for [category].
Future<void> showBudgetEditor(
  BuildContext context,
  TransactionCategory category,
  Money? current,
) {
  final controller = TextEditingController(
    text: current == null ? '' : '${current.amount.round()}',
  );
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return Consumer(
        builder: (context, ref, _) {
          final session = ref.read(sessionProvider.notifier);
          return AlertDialog(
            title: Text(l10n.budgetsEditTitle(l10n.transactionCategory(category))),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.budgetsLimitLabel,
                prefixText: 'CHF ',
              ),
            ),
            actions: [
              if (current != null)
                TextButton(
                  onPressed: () {
                    session.setBudget(category, null);
                    Navigator.pop(dialogContext);
                  },
                  child: Text(l10n.budgetsRemove),
                ),
              FilledButton(
                onPressed: () {
                  final francs = int.tryParse(controller.text) ?? 0;
                  session.setBudget(category, Money.cents(francs * 100));
                  Navigator.pop(dialogContext);
                },
                child: Text(l10n.saveAsset),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}
