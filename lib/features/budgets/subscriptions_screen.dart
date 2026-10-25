import 'package:finora/app/theme.dart';
import 'package:finora/application/budgets.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/budgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional subscriptions: decide what to keep, plan cancellations and see
/// the saving once they are done.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plan = ref.watch(subscriptionPlanProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.subscriptionsTitle),
      ),
      body: FinoraPage(
        child: plan.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.overviewUnavailable)),
          data: (data) => ListView(
            children: [
              KeyFigureGrid(
                figures: [
                  (l10n.subscriptionsYearly, formatMoneyWhole(data.yearlyTotal)),
                  (l10n.subscriptionsPlanned, formatMoneyWhole(data.plannedSaving)),
                  (l10n.subscriptionsAchieved, formatMoneyWhole(data.achievedSaving)),
                  (l10n.subscriptionsUndecided, '${data.undecided}'),
                ],
              ),
              SectionTitle(l10n.subscriptionsListSection),
              if (data.items.isEmpty)
                Text(
                  l10n.subscriptionsEmpty,
                  style: const TextStyle(color: finoraMutedInk),
                )
              else
                for (final item in data.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SubscriptionCard(item: item),
                  ),
              Text(
                l10n.subscriptionsNote,
                style: const TextStyle(color: finoraMutedInk, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.item});
  final SubscriptionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.read(sessionProvider.notifier);
    final merchant = item.payment.merchant;
    final decision = item.decision;
    final cancelled = decision == SubscriptionDecision.cancelled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    merchant,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Text(
                  l10n.perMonth(formatMoney(item.monthly)),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Text(
              '${l10n.billCategory(item.payment.category)} · ${l10n.subscriptionsPerYear(formatMoneyWhole(item.yearly))}',
              style: const TextStyle(color: finoraMutedInk, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (cancelled)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: finoraGreen, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.subscriptionsCancelledSaving(
                        formatMoneyWhole(item.yearly),
                      ),
                      style: const TextStyle(color: finoraGreen),
                    ),
                  ),
                  TextButton(
                    onPressed: () => session.decideSubscription(merchant, null),
                    child: Text(l10n.commonUndo),
                  ),
                ],
              )
            else ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l10n.subscriptionsKeep),
                    selected: decision == SubscriptionDecision.keep,
                    onSelected: (_) => session.decideSubscription(
                      merchant,
                      SubscriptionDecision.keep,
                    ),
                  ),
                  ChoiceChip(
                    label: Text(l10n.subscriptionsToCancel),
                    selected: decision == SubscriptionDecision.toCancel,
                    onSelected: (_) => session.decideSubscription(
                      merchant,
                      SubscriptionDecision.toCancel,
                    ),
                  ),
                ],
              ),
              if (decision == SubscriptionDecision.toCancel) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.subscriptionsHowToCancel(merchant),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => session.decideSubscription(
                      merchant,
                      SubscriptionDecision.cancelled,
                    ),
                    icon: const Icon(Icons.done),
                    label: Text(l10n.subscriptionsMarkCancelled),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
