import 'package:finora/app/theme.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/category_rules.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets the user pick the category of a booking; the choice applies to
/// every booking from the same merchant.
Future<void> showCategorySheet(
  BuildContext context,
  FinancialTransaction transaction,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _CategorySheet(transaction: transaction),
);

class _CategorySheet extends ConsumerWidget {
  const _CategorySheet({required this.transaction});
  final FinancialTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ruled = ref.watch(
      sessionProvider.select(
        (session) => session.categoryRules.containsKey(
          CategoryRules.keyOf(transaction.merchant),
        ),
      ),
    );
    void choose(TransactionCategory? category) {
      ref
          .read(sessionProvider.notifier)
          .setCategoryRule(transaction.merchant, category);
      Navigator.of(context).pop();
      if (category != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              l10n.categoryChanged(
                transaction.merchant,
                l10n.transactionCategory(category),
              ),
            ),
          ),
        );
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction.merchant,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.categorySheetRule(transaction.merchant),
              style: const TextStyle(color: finoraMutedInk),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in TransactionCategory.values)
                  ChoiceChip(
                    label: Text(l10n.transactionCategory(category)),
                    selected: category == transaction.category,
                    onSelected: (_) => choose(category),
                  ),
              ],
            ),
            if (ruled) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => choose(null),
                icon: const Icon(Icons.undo),
                label: Text(l10n.categorySheetReset),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
