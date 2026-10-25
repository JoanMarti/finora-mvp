import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

IconData opportunityIcon(OpportunityCategory category) => switch (category) {
  OpportunityCategory.insurance => Icons.health_and_safety_outlined,
  OpportunityCategory.banking => Icons.account_balance_outlined,
  OpportunityCategory.pensions => Icons.savings_outlined,
  OpportunityCategory.mortgage => Icons.home_work_outlined,
  OpportunityCategory.telecom => Icons.wifi,
  OpportunityCategory.budget => Icons.subscriptions_outlined,
};

/// Compact banner for one savings opportunity. Sponsored ones carry a
/// visible "Partner offer" label.
class OpportunityBanner extends StatelessWidget {
  const OpportunityBanner({required this.opportunity, super.key});
  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saving = l10n.opportunitySaving(opportunity);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showOpportunitySheet(context, opportunity),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: finoraMint,
                foregroundColor: finoraGreen,
                child: Icon(opportunityIcon(opportunity.category), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        l10n.opportunityCategory(opportunity.category),
                        if (opportunity.isSponsored) l10n.offerPartnerLabel,
                      ].join(' · ').toUpperCase(),
                      style: const TextStyle(
                        color: finoraMutedInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.opportunityTitle(opportunity),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (saving != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        saving,
                        style: const TextStyle(
                          color: finoraGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: finoraMutedInk),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the explanation for [opportunity]: why it appears, what it could
/// save, how Finora is paid and an explicit consent before anything is
/// shared with a partner.
Future<void> showOpportunitySheet(BuildContext context, Opportunity opportunity) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OpportunitySheet(opportunity: opportunity),
  );
}

class _OpportunitySheet extends ConsumerStatefulWidget {
  const _OpportunitySheet({required this.opportunity});
  final Opportunity opportunity;

  @override
  ConsumerState<_OpportunitySheet> createState() => _OpportunitySheetState();
}

class _OpportunitySheetState extends ConsumerState<_OpportunitySheet> {
  bool _shareConsent = false;

  @override
  void initState() {
    super.initState();
    // Logged after the first frame so building never mutates state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(sessionProvider.notifier)
            .recordOfferEvent(widget.opportunity, OfferEventType.viewed);
      }
    });
  }

  Future<void> _continue() async {
    final opportunity = widget.opportunity;
    final session = ref.read(sessionProvider.notifier);
    session.recordOfferEvent(opportunity, OfferEventType.partnerClicked);
    if (opportunity.isSponsored) session.recordPartnerConsent(opportunity.kind);
    if (!opportunity.isSponsored) {
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push(
        opportunity.kind == OpportunityKind.subscriptionsReview
            ? '/subscriptions'
            : '/analysis',
      );
      return;
    }
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.offerDemoTitle),
        content: Text(l10n.offerDemoBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  void _dismiss() {
    final opportunity = widget.opportunity;
    ref.read(sessionProvider.notifier)
      ..recordOfferEvent(opportunity, OfferEventType.dismissed)
      ..dismissOpportunity(opportunity.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final opportunity = widget.opportunity;
    final saving = l10n.opportunitySaving(opportunity);
    final canContinue = !opportunity.isSponsored || _shareConsent;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ValuePill(
                  label: l10n.opportunityCategory(opportunity.category),
                  color: finoraBlue,
                ),
                if (opportunity.isSponsored) ...[
                  const SizedBox(width: 8),
                  ValuePill(label: l10n.offerPartnerLabel, color: finoraSlate),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.opportunityTitle(opportunity),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (saving != null) ...[
              const SizedBox(height: 8),
              Text(
                saving,
                style: const TextStyle(
                  color: finoraGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SheetSection(
              icon: Icons.insights_outlined,
              title: l10n.offerWhyTitle,
              body: l10n.opportunityReason(opportunity),
            ),
            if (saving != null)
              _SheetSection(
                icon: Icons.calculate_outlined,
                title: l10n.offerEstimateTitle,
                body: l10n.offerEstimateBody,
              ),
            _SheetSection(
              icon: Icons.handshake_outlined,
              title: l10n.offerHowPaidTitle,
              body: l10n.revenueDisclosure(opportunity.revenue),
            ),
            if (opportunity.isSponsored)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _shareConsent,
                onChanged: (value) =>
                    setState(() => _shareConsent = value ?? false),
                title: Text(
                  l10n.offerShareConsent,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: canContinue ? _continue : null,
              child: Text(l10n.opportunityAction(opportunity)),
            ),
            TextButton(
              onPressed: _dismiss,
              child: Text(l10n.offerNotInterested),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: finoraBlueText, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Asks once for express consent before any data-based offers are shown.
class OffersConsentCard extends ConsumerWidget {
  const OffersConsentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.read(sessionProvider.notifier);
    return Card(
      color: finoraMint,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_outlined, color: finoraGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.offersConsentTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.offersConsentBody, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => session.setOffersConsent(true),
                    child: Text(l10n.offersConsentAccept),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => session.setOffersConsent(false),
                  child: Text(l10n.offersConsentDecline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard section: consent request, or the best opportunities.
class SavingsOpportunitiesSection extends ConsumerWidget {
  const SavingsOpportunitiesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final consent = ref.watch(
      sessionProvider.select((session) => session.offersConsent),
    );
    if (consent == false) return const SizedBox.shrink();
    if (consent == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(l10n.waysToSaveSection),
          const OffersConsentCard(),
        ],
      );
    }
    final items = ref.watch(opportunitiesProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final total = ref.watch(potentialSavingProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          l10n.waysToSaveSection,
          action: TextButton(
            onPressed: () => context.push('/offers'),
            child: Text(l10n.seeAll),
          ),
        ),
        Text(
          l10n.potentialSaving(formatMoneyWhole(total)),
          style: const TextStyle(
            color: finoraGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in items.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OpportunityBanner(opportunity: item),
          ),
      ],
    );
  }
}

/// Small suggestion shown next to the data it is about (a bill, an
/// account). Tapping it opens the full explanation and consent sheet.
class InlineOfferHint extends StatelessWidget {
  const InlineOfferHint({required this.opportunity, super.key});
  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final saving = opportunity.savingHigh == null
        ? null
        : formatMoneyWhole(opportunity.savingHigh!);
    return Material(
      color: finoraMint,
      borderRadius: BorderRadius.circular(finoraRadiusControl),
      child: InkWell(
        borderRadius: BorderRadius.circular(finoraRadiusControl),
        onTap: () => showOpportunitySheet(context, opportunity),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: finoraGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saving == null
                          ? l10n.opportunityTitle(opportunity)
                          : l10n.hintSaveUpTo(saving),
                      style: const TextStyle(
                        color: finoraGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      [
                        l10n.opportunityTitle(opportunity),
                        if (opportunity.isSponsored) l10n.offerPartnerLabel,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: finoraInk,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: finoraGreen),
            ],
          ),
        ),
      ),
    );
  }
}
