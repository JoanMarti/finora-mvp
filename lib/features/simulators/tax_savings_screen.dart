import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/profile.dart';
import 'package:finora/domain/simulators.dart';
import 'package:finora/features/simulators/simulator_widgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// How much tax a Pillar 3a contribution or a pension fund buy-in saves.
class TaxSavingsScreen extends ConsumerStatefulWidget {
  const TaxSavingsScreen({super.key});

  @override
  ConsumerState<TaxSavingsScreen> createState() => _TaxSavingsScreenState();
}

class _TaxSavingsScreenState extends ConsumerState<TaxSavingsScreen> {
  Money? _pillar3a;
  Money _buyIn = Money.zero;
  /// The user's own rate; until they move the slider, an estimate from the
  /// profile (or a middle default).
  double? _rate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overview = ref.watch(overviewProvider).value;
    final projection = ref.watch(retirementProjectionProvider).value;
    if (overview == null || projection == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final limit = ref.watch(wealthTargetsProvider).pillar3aAnnualLimit;
    final estimate = ProfileEstimates.marginalRate(
      ref.watch(userProfileProvider),
    );
    final rate = _rate ?? estimate ?? TaxSavings.defaultRate;
    final room = limit - overview.pillar3aContributionsThisYear;
    // Starts with what is still allowed this year.
    final pillar3a = _pillar3a ??= room.cents > 0 ? room : Money.zero;
    final result = TaxSavings.simulate(
      pillar3aContribution: pillar3a,
      buyIn: _buyIn,
      marginalRate: rate,
      yearsToRetirement: projection.yearsToRetirement,
    );
    final overLimit = pillar3a.cents > room.cents;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.taxSavingsTitle),
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
                    Text(l10n.taxSavingsResult),
                    const SizedBox(height: 6),
                    Text(
                      formatMoneyWhole(result.taxSaving),
                      style: const TextStyle(
                        color: finoraGreen,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ResultRow(
                      label: l10n.taxSavingsDeductions,
                      value: formatMoneyWhole(result.deductions),
                    ),
                    ResultRow(
                      label: l10n.taxSavingsNetCost,
                      value: formatMoneyWhole(result.netCost),
                      emphasised: true,
                    ),
                    if (!_buyIn.isZero)
                      ResultRow(
                        label: l10n.taxSavingsExtraPension,
                        value: l10n.perMonth(
                          formatMoney(result.extraMonthlyPension),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
        inputs: [
            SectionTitle(l10n.productPillar3a),
            MoneyField(
              label: l10n.taxSavingsPillarLabel,
              helper: l10n.taxSavingsPillarHelp(formatMoneyWhole(room)),
              value: pillar3a,
              onChanged: (value) => setState(() => _pillar3a = value),
            ),
            if (overLimit) SimulatorNote(l10n.taxSavingsOverLimit),
            SectionTitle(l10n.taxSavingsBuyInSection),
            MoneyField(
              label: l10n.taxSavingsBuyInLabel,
              helper: l10n.taxSavingsBuyInHelp,
              value: _buyIn,
              onChanged: (value) => setState(() => _buyIn = value),
            ),
            SectionTitle(l10n.taxSavingsRateSection),
            Text(
              l10n.taxSavingsRateLabel((rate * 100).round()),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Slider(
              value: rate,
              min: TaxSavings.minRate,
              max: TaxSavings.maxRate,
              divisions: 35,
              label: '${(rate * 100).round()}%',
              onChanged: (value) => setState(() => _rate = value),
            ),
            if (_rate == null && estimate != null)
              SimulatorNote(l10n.taxRateFromProfile),
            SimulatorNote(l10n.taxSavingsRateHelp),
        ],
        details: [
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/offers'),
              icon: const Icon(Icons.savings_outlined),
              label: Text(l10n.offerPillarAction),
            ),
            SimulatorNote(l10n.taxSavingsBuyInLock(TaxSavings.buyInLockYears)),
            SimulatorNote(l10n.taxSavingsDisclaimer),
        ],
      ),
    );
  }
}
