import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Finora Plus: what it adds, what stays free, and the (demo) purchase.
class PlusScreen extends ConsumerWidget {
  const PlusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isPlus = ref.watch(isPlusProvider);
    final since = ref.watch(
      sessionProvider.select((session) => session.plusSince),
    );
    final price = formatMoneyWhole(PlusPricing.yearly);
    final features = [
      (
        Icons.alt_route,
        l10n.plusFeatureScenariosTitle,
        l10n.plusFeatureScenariosBody,
        false,
      ),
      (
        Icons.receipt_long_outlined,
        l10n.plusFeatureTaxTitle,
        l10n.plusFeatureTaxBody,
        false,
      ),
      (
        Icons.family_restroom,
        l10n.plusFeatureHouseholdTitle,
        l10n.plusFeatureHouseholdBody,
        false,
      ),
      (
        Icons.history,
        l10n.plusFeatureHistoryTitle,
        l10n.plusFeatureHistoryBody,
        true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.plusTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            Card(
              color: finoraInk,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF8ED8B9)),
                    const SizedBox(height: 10),
                    Text(
                      l10n.plusHeadline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.plusSubtitle,
                      style: const TextStyle(color: finoraSilver, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.plusPricePerYear(price),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SectionTitle(l10n.plusIncludedSection),
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < features.length; index++) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: finoraSoftBlue,
                        foregroundColor: finoraBlueText,
                        child: Icon(features[index].$1, size: 20),
                      ),
                      title: Text(
                        features[index].$2,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(features[index].$3),
                      trailing: features[index].$4
                          ? ValuePill(label: l10n.comingSoon, color: finoraSlate)
                          : const Icon(Icons.check, color: finoraGreen),
                    ),
                    if (index != features.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: finoraMint,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Promise(text: l10n.plusFreeForever),
                    _Promise(text: l10n.plusNoOfferInfluence),
                    _Promise(text: l10n.plusCancelAnytime),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isPlus) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.verified, color: finoraGreen),
                  title: Text(
                    l10n.plusActive,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: since == null
                      ? null
                      : Text(
                          l10n.plusActiveSince(
                            DateFormat.yMMMd(l10n.localeName).format(since),
                          ),
                        ),
                ),
              ),
              TextButton(
                onPressed: () => _confirmCancel(context, ref),
                child: Text(l10n.plusCancel),
              ),
            ] else
              FilledButton(
                onPressed: () => _confirmStart(context, ref),
                child: Text(l10n.plusStart(price)),
              ),
            const SizedBox(height: 12),
            Text(
              l10n.plusDemoNote,
              textAlign: TextAlign.center,
              style: const TextStyle(color: finoraMutedInk, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmStart(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.plusConfirmTitle),
        content: Text(dialogContext.l10n.plusConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.plusConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(sessionProvider.notifier).startPlus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.plusWelcome)));
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.plusCancelTitle),
        content: Text(dialogContext.l10n.plusCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.plusKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.plusCancel),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(sessionProvider.notifier).cancelPlus();
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: finoraGreen, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}

/// Placeholder shown where a Plus feature would be, with a way to unlock it.
class PlusLockedCard extends StatelessWidget {
  const PlusLockedCard({required this.title, required this.body, super.key});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: finoraSoftBlue,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, color: finoraBlueText, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ValuePill(label: l10n.plusBadge, color: finoraBlue),
              ],
            ),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.4)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/plus'),
                child: Text(l10n.plusUnlock),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
