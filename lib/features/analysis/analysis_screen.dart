import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/analysis.dart';
import 'package:finora/features/accounts/widgets/account_analytics_cards.dart';
import 'package:finora/features/offers/widgets/opportunity_widgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Spending analysis across every everyday account.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  bool _showAllBills = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final analysis = ref.watch(spendingAnalysisProvider);
    final now = ref.watch(clockProvider)();
    final opportunities = ref.watch(opportunitiesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.analysisTitle),
      ),
      body: FinoraPage(
        child: analysis.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.overviewUnavailable)),
          data: (data) {
            if (data.isEmpty) {
              return Center(
                child: Text(
                  l10n.analysisEmpty,
                  textAlign: TextAlign.center,
                ),
              );
            }
            final combined = data.combined;
            return ListView(
              children: [
                Text(
                  l10n.analysisHeadline,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.analysisSubtitle(data.accountCount),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                _KeyFigures(analysis: data),
                if (combined.hasCashFlow) ...[
                  SectionTitle(l10n.cashFlowSection),
                  CashFlowCard(analytics: combined, months: 6),
                ],
                if (combined.spendingCategories.isNotEmpty) ...[
                  SectionTitle(l10n.spendingSection),
                  SpendingCategoriesCard(analytics: combined),
                ],
                if (combined.recurringPayments.isNotEmpty) ...[
                  SectionTitle(
                    l10n.fixedCostsSection,
                    action: combined.recurringPayments.length > 3
                        ? TextButton(
                            onPressed: () =>
                                setState(() => _showAllBills = !_showAllBills),
                            child: Text(
                              _showAllBills ? l10n.showLess : l10n.seeAll,
                            ),
                          )
                        : null,
                  ),
                  RecurringPaymentsCard(
                    analytics: combined,
                    showAll: _showAllBills,
                    now: now,
                  ),
                ],
                if (opportunities.isNotEmpty) ...[
                  SectionTitle(l10n.waysToSaveSection),
                  for (final item in opportunities.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OpportunityBanner(opportunity: item),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KeyFigures extends StatelessWidget {
  const _KeyFigures({required this.analysis});
  final SpendingAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final combined = analysis.combined;
    final largest = analysis.largestCategory;
    final figures = [
      (l10n.savingsRateLabel, '${(combined.savingsRate * 100).round()}%'),
      (
        l10n.fixedCostShareLabel,
        '${(analysis.fixedCostShare * 100).round()}%',
      ),
      (l10n.recurringYearlyLabel, formatMoneyWhole(analysis.recurringYearly)),
      (
        l10n.largestCategoryLabel,
        largest == null ? '–' : l10n.transactionCategory(largest.category),
      ),
    ];
    return KeyFigureGrid(figures: figures);
  }
}
