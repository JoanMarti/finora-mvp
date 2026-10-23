import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/features/offers/widgets/opportunity_widgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every savings opportunity found in the user's data, with filters and the
/// principles that govern partner offers.
class OpportunitiesScreen extends ConsumerStatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  ConsumerState<OpportunitiesScreen> createState() =>
      _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends ConsumerState<OpportunitiesScreen> {
  OpportunityCategory? _category;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final consent = ref.watch(
      sessionProvider.select((session) => session.offersConsent),
    );
    final opportunities = ref.watch(opportunitiesProvider);
    final total = ref.watch(potentialSavingProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.waysToSaveSection),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            if (consent != true) ...[
              const OffersConsentCard(),
            ] else
              opportunities.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Text(l10n.overviewUnavailable),
                data: (items) {
                  final categories = {for (final item in items) item.category};
                  final visible = [
                    for (final item in items)
                      if (_category == null || item.category == _category) item,
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.potentialSaving(formatMoneyWhole(total)),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.offersSubtitle(items.length),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: Text(l10n.filterAll),
                              selected: _category == null,
                              onSelected: (_) =>
                                  setState(() => _category = null),
                            ),
                            for (final category in categories) ...[
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text(l10n.opportunityCategory(category)),
                                selected: _category == category,
                                onSelected: (_) =>
                                    setState(() => _category = category),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (visible.isEmpty)
                        Text(
                          l10n.noOffers,
                          style: const TextStyle(color: finoraMutedInk),
                        ),
                      for (final item in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OpportunityBanner(opportunity: item),
                        ),
                    ],
                  );
                },
              ),
            SectionTitle(l10n.offerPrinciplesTitle),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Column(
                  children: [
                    for (final line in [
                      l10n.offerPrincipleData,
                      l10n.offerPrincipleRanking,
                      l10n.offerPrincipleConsent,
                      l10n.offerPrincipleRegulated,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: finoraGreen,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                line,
                                style: const TextStyle(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
