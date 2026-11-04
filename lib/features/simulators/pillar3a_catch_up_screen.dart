import 'package:finora/app/theme.dart';
import 'package:finora/application/pillar3a_catch_up.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/pillar3a_catch_up.dart';
import 'package:finora/domain/profile.dart';
import 'package:finora/domain/simulators.dart';
import 'package:finora/features/simulators/simulator_widgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Retroactive Pillar 3a purchases for the years since 2025.
class Pillar3aCatchUpScreen extends ConsumerStatefulWidget {
  const Pillar3aCatchUpScreen({super.key});

  @override
  ConsumerState<Pillar3aCatchUpScreen> createState() =>
      _Pillar3aCatchUpScreenState();
}

class _Pillar3aCatchUpScreenState extends ConsumerState<Pillar3aCatchUpScreen> {
  /// What the user corrected, by year.
  final _paid = <int, Money>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overview = ref.watch(overviewProvider).value;
    final known = ref.watch(pillar3aPaidByYearProvider).value;
    if (overview == null || known == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final now = ref.watch(clockProvider)();
    final plan = Pillar3aCatchUpPlan.build(
      year: now.year,
      paidByYear: {...known, ..._paid},
      currentMaximum: ref.watch(wealthTargetsProvider).pillar3aAnnualLimit,
      paidThisYear: overview.pillar3aContributionsThisYear,
    );
    final rate =
        ProfileEstimates.marginalRate(ref.watch(userProfileProvider)) ??
        TaxSavings.defaultRate;
    final purchasable = plan.purchasableThisYear;

    Widget condition(String text, {bool? met}) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        met == false ? Icons.radio_button_unchecked : Icons.check_circle,
        color: met == false ? finoraWarning : finoraGreen,
      ),
      title: Text(text),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.catchUpTitle),
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
                  if (purchasable.isZero)
                    Text(
                      l10n.catchUpNoGaps,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )
                  else ...[
                    Text(
                      l10n.catchUpCanPay(formatMoneyWhole(purchasable)),
                      style: const TextStyle(
                        color: finoraGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.catchUpSaves(formatMoneyWhole(plan.taxSaving(rate))),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        inputs: [
          Text(l10n.catchUpIntro),
          SectionTitle(l10n.catchUpGapsSection),
          for (final gap in plan.gaps) ...[
            MoneyField(
              label: l10n.catchUpPaidLabel(gap.year),
              helper: l10n.catchUpGapLine(
                formatMoneyWhole(gap.gap),
                gap.lastYear,
              ),
              value: gap.paid,
              onChanged: (value) => setState(() => _paid[gap.year] = value),
            ),
            const SizedBox(height: 8),
          ],
        ],
        details: [
          SectionTitle(l10n.catchUpConditions),
          condition(
            plan.currentYearFull
                ? l10n.catchUpConditionCurrent
                : l10n.catchUpConditionCurrentMissing(
                    formatMoneyWhole(plan.currentYearRoom),
                  ),
            met: plan.currentYearFull,
          ),
          condition(l10n.catchUpConditionIncome),
          condition(l10n.catchUpConditionNoWithdrawal),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/tax-savings'),
            icon: const Icon(Icons.calculate_outlined),
            label: Text(l10n.taxSavingsTitle),
          ),
          SimulatorNote(
            l10n.catchUpCapNote(
              formatMoneyWhole(Pillar3aCatchUpRules.smallMaximum(now.year)),
            ),
          ),
          SimulatorNote(
            l10n.catchUpDeadline(
              DateFormat.yMMMd(l10n.localeName).format(plan.deadline),
            ),
          ),
          SimulatorNote(l10n.catchUpDisclaimer),
        ],
      ),
    );
  }
}
