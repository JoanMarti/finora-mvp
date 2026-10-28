import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/health_insurance.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/simulators/simulator_widgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Which health insurance deductible costs least for the expected costs.
class HealthInsuranceScreen extends ConsumerStatefulWidget {
  const HealthInsuranceScreen({super.key});

  /// Premium used when no health insurance bill is found (average adult
  /// premium for 2027, rounded).
  static const fallbackPremium = Money.cents(41000);

  static const defaultCosts = Money.cents(50000);

  @override
  ConsumerState<HealthInsuranceScreen> createState() =>
      _HealthInsuranceScreenState();
}

class _HealthInsuranceScreenState extends ConsumerState<HealthInsuranceScreen> {
  Money? _premium;
  int _deductible = 300;
  Money _costs = HealthInsuranceScreen.defaultCosts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final analysis = ref.watch(spendingAnalysisProvider);
    if (analysis.isLoading && !analysis.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bill = analysis.value?.combined.recurringPayments
        .where((payment) => payment.category == BillCategory.healthInsurance)
        .firstOrNull;
    final premium = _premium ??=
        bill?.amount.abs() ?? HealthInsuranceScreen.fallbackPremium;
    final comparison = DeductibleComparison.estimate(
      monthlyPremium: premium,
      currentDeductible: _deductible,
      expectedCosts: _costs,
    );
    final best = comparison.best;
    final saving = comparison.yearlySaving;
    final now = ref.watch(clockProvider)();
    final deadline = SwissHealthInsuranceRules.changeDeadline(now);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.healthInsTitle),
      ),
      body: SimulatorLayout(
        summary: [
          Card(
            color: finoraMint,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.healthInsBest),
                  const SizedBox(height: 6),
                  Text(
                    formatMoneyWhole(Money.cents(best.deductible * 100)),
                    style: const TextStyle(
                      color: finoraGreen,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    saving.cents > 0
                        ? l10n.healthInsSaving(formatMoneyWhole(saving))
                        : l10n.healthInsAlreadyBest,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.healthInsWorstCase(formatMoneyWhole(best.worstCase)),
                    style: const TextStyle(color: finoraMutedInk),
                  ),
                ],
              ),
            ),
          ),
        ],
        inputs: [
          MoneyField(
            label: l10n.healthInsPremiumLabel,
            helper: bill == null
                ? null
                : l10n.healthInsPremiumFromBills(bill.merchant),
            value: premium,
            onChanged: (value) => setState(() => _premium = value),
          ),
          SectionTitle(l10n.healthInsCurrentSection),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final deductible
                  in SwissHealthInsuranceRules.adultDeductibles)
                ChoiceChip(
                  label: Text(
                    formatMoneyWhole(Money.cents(deductible * 100)),
                  ),
                  selected: deductible == _deductible,
                  onSelected: (_) => setState(() => _deductible = deductible),
                ),
            ],
          ),
          SimulatorNote(l10n.healthInsAdultsOnly),
          const SizedBox(height: 8),
          MoneyField(
            label: l10n.healthInsCostsLabel,
            helper: l10n.healthInsCostsHelp,
            value: _costs,
            onChanged: (value) => setState(() => _costs = value),
          ),
        ],
        details: [
          SectionTitle(l10n.healthInsTableSection),
          Card(
            child: Column(
              children: [
                for (final option in comparison.options)
                  ListTile(
                    dense: true,
                    title: Text(
                      formatMoneyWhole(Money.cents(option.deductible * 100)),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      l10n.healthInsOptionLine(
                        formatMoneyWhole(option.yearlyPremium),
                        formatMoneyWhole(option.outOfPocket),
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (identical(option, best))
                          ValuePill(
                            label: l10n.healthInsBestTag,
                            color: finoraGreen,
                          )
                        else if (option.deductible == _deductible)
                          ValuePill(
                            label: l10n.healthInsCurrentTag,
                            color: finoraSlate,
                          ),
                        Text(
                          formatMoneyWhole(option.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFeatures: finoraTabular,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/offers'),
            icon: const Icon(Icons.compare_arrows),
            label: Text(l10n.healthInsCompare),
          ),
          SimulatorNote(
            l10n.healthInsDeadline(
              now.year + 1,
              DateFormat.yMMMd(l10n.localeName).format(deadline),
            ),
          ),
          SimulatorNote(l10n.healthInsDisclaimer),
        ],
      ),
    );
  }
}
