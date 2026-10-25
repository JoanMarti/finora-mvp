import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/price_changes.dart';
import 'package:finora/features/offers/widgets/opportunity_widgets.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Every recurring charge that went up, with what to compare (Premium).
class PriceAlertsScreen extends ConsumerWidget {
  const PriceAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final premium = ref.watch(isPlusProvider);
    final changes =
        ref.watch(priceChangesProvider).value ?? const <PriceChange>[];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.priceAlertsTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            Text(
              l10n.priceAlertsSubtitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (!premium)
              PlusLockedCard(
                title: l10n.priceAlertsLockedTitle(changes.length),
                body: l10n.priceAlertsLockedBody,
              )
            else if (changes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.priceAlertsEmpty,
                    style: const TextStyle(color: finoraMutedInk),
                  ),
                ),
              )
            else
              for (final change in changes) ...[
                _PriceChangeCard(change: change),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 8),
            Text(
              l10n.priceAlertsHow,
              style: const TextStyle(color: finoraMutedInk, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceChangeCard extends ConsumerWidget {
  const _PriceChangeCard({required this.change});
  final PriceChange change;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const TonalIcon(Icons.trending_up, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        change.merchant,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        priceChangeLine(l10n, change),
                        style: const TextStyle(
                          color: finoraMutedInk,
                          fontFeatures: finoraTabular,
                        ),
                      ),
                    ],
                  ),
                ),
                ValuePill(
                  label: l10n.priceAlertYearly(
                    formatMoneyWhole(change.yearlyImpact),
                  ),
                  color: finoraWarning,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 4),
              child: Text(
                l10n.priceAlertSince(
                  DateFormat.MMMd(l10n.localeName).format(change.since),
                ),
                style: const TextStyle(color: finoraMutedInk, fontSize: 12),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _compare(context, ref),
                child: Text(l10n.priceAlertCompare),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The matching savings offer when there is one, else the place where
  /// the charge can be reviewed.
  Future<void> _compare(BuildContext context, WidgetRef ref) async {
    final kind = relatedOfferKind(change);
    final router = GoRouter.of(context);
    var offers = const <Opportunity>[];
    if (kind != null) {
      try {
        offers = await ref.read(opportunitiesProvider.future);
      } on Object {
        offers = const [];
      }
    }
    if (!context.mounted) return;
    final offer = kind == null
        ? null
        : offers.where((item) => item.kind == kind).firstOrNull;
    if (offer != null) {
      showOpportunitySheet(context, offer);
      return;
    }
    router.push(
      kind == OpportunityKind.subscriptionsReview ? '/subscriptions' : '/analysis',
    );
  }
}

/// "CHF 84.90 → CHF 89.90 · +6%".
String priceChangeLine(AppLocalizations l10n, PriceChange change) =>
    l10n.priceAlertRow(
      formatMoney(change.previous),
      formatMoney(change.current),
      (change.rate * 100).round(),
    );

/// Which savings offer helps with a charge that went up.
OpportunityKind? relatedOfferKind(PriceChange change) {
  final merchant = change.merchant.toLowerCase();
  const telecom = ['swisscom', 'sunrise', 'salt', 'wingo', 'yallo', 'upc'];
  if (telecom.any(merchant.contains)) return OpportunityKind.telecomPlan;
  if (change.category == TransactionCategory.insurance) {
    return OpportunityKind.insuranceReview;
  }
  if (change.category == TransactionCategory.shopping ||
      change.category == TransactionCategory.other) {
    return OpportunityKind.subscriptionsReview;
  }
  return null;
}

/// Dashboard card: the biggest increases with Premium, a count without.
class PriceAlertsCard extends ConsumerWidget {
  const PriceAlertsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final changes =
        ref.watch(priceChangesProvider).value ?? const <PriceChange>[];
    if (changes.isEmpty) return const SizedBox.shrink();
    final premium = ref.watch(isPlusProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(premium ? '/price-alerts' : '/plus'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: finoraWarning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        premium
                            ? l10n.priceAlertsTitle
                            : l10n.priceAlertsLockedTitle(changes.length),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (!premium)
                      ValuePill(label: l10n.plusBadge, color: finoraBlue),
                    const Icon(Icons.chevron_right, color: finoraSlate),
                  ],
                ),
                const SizedBox(height: 8),
                if (premium)
                  for (final change in changes.take(2))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              change.merchant,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            priceChangeLine(l10n, change),
                            style: const TextStyle(
                              color: finoraMutedInk,
                              fontSize: 13,
                              fontFeatures: finoraTabular,
                            ),
                          ),
                        ],
                      ),
                    )
                else
                  Text(
                    l10n.priceAlertsLockedBody,
                    style: const TextStyle(color: finoraMutedInk, height: 1.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
