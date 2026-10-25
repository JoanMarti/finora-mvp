import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onboarding: start on Free or try Premium. Both buttons carry the same
/// weight; Free has no time limit.
class PlanStep extends ConsumerStatefulWidget {
  const PlanStep({required this.onContinue, super.key});
  final VoidCallback onContinue;

  @override
  ConsumerState<PlanStep> createState() => _PlanStepState();
}

class _PlanStepState extends ConsumerState<PlanStep> {
  BillingPeriod _period = BillingPeriod.yearly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider);
    final premium = session.isPlus;
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        children: [
          Text(
            l10n.planChooseTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.planChooseBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          BillingToggle(
            period: _period,
            onChanged: (period) => setState(() => _period = period),
          ),
          const SizedBox(height: 14),
          PlanCards(
            period: _period,
            wide: constraints.maxWidth >= 640,
            currentIsPremium: premium,
            freeAction: (
              label: premium ? l10n.planStayFree : l10n.planStartFree,
              onPressed: () {
                if (premium) ref.read(sessionProvider.notifier).cancelPlus();
                widget.onContinue();
              },
            ),
            premiumAction: premium
                ? (label: l10n.commonContinue, onPressed: widget.onContinue)
                : session.trialUsed
                ? null
                : (
                    label: l10n.trialStart(PlusPricing.trialDays),
                    onPressed: () {
                      ref.read(sessionProvider.notifier).startTrial();
                      widget.onContinue();
                    },
                  ),
            premiumFootnote: session.trialUsed
                ? null
                : l10n.trialTerms(PlusPricing.trialReminderDays),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
