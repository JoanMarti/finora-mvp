import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The business-plan funnel KPIs as this device measures them. In the pilot
/// the same aggregated counts go to the analytics backend.
class PilotMetricsScreen extends ConsumerWidget {
  const PilotMetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final funnel = ref.watch(funnelProvider);
    final consent = ref.watch(
      sessionProvider.select((session) => session.offersConsent),
    );
    final isPlus = ref.watch(isPlusProvider);
    String percent(double rate) => '${(rate * 100).round()}%';
    final pursued = funnel.pursuedSavingHigh.isZero
        ? '–'
        : l10n.moneyRange(
            formatMoneyWhole(funnel.pursuedSavingLow),
            formatMoneyWhole(funnel.pursuedSavingHigh),
          );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.pilotMetricsTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            Text(
              l10n.pilotMetricsIntro,
              style: const TextStyle(color: finoraMutedInk, height: 1.4),
            ),
            const SizedBox(height: 16),
            KeyFigureGrid(
              figures: [
                (
                  l10n.kpiConsent,
                  switch (consent) {
                    true => l10n.kpiConsentGiven,
                    false => l10n.kpiConsentDeclined,
                    null => l10n.kpiConsentNotAsked,
                  },
                ),
                (l10n.kpiOffersOpened, '${funnel.count(OfferEventType.viewed)}'),
                (l10n.kpiClickRate, percent(funnel.clickRate)),
                (l10n.kpiDismissRate, percent(funnel.dismissRate)),
                (l10n.kpiSavingPursued, pursued),
                (l10n.kpiPlan, isPlus ? l10n.plusBadge : l10n.planFree),
              ],
            ),
            SectionTitle(l10n.kpiByOfferSection),
            if (funnel.isEmpty)
              Text(
                l10n.kpiEmpty,
                style: const TextStyle(color: finoraMutedInk, height: 1.4),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _FunnelRow(
                        label: l10n.kpiOfferColumn,
                        values: [
                          l10n.kpiViewsShort,
                          l10n.kpiClicksShort,
                          l10n.kpiDismissedShort,
                        ],
                        header: true,
                      ),
                      for (final kind in funnel.kinds)
                        _FunnelRow(
                          label: l10n.offerKindTitle(kind),
                          values: [
                            for (final type in OfferEventType.values)
                              '${funnel.count(type, kind: kind)}',
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              l10n.pilotMetricsPrivacy,
              style: const TextStyle(
                color: finoraMutedInk,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunnelRow extends StatelessWidget {
  const _FunnelRow({
    required this.label,
    required this.values,
    this.header = false,
  });
  final String label;
  final List<String> values;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: header ? 11 : 13,
      color: header ? finoraMutedInk : finoraInk,
      fontWeight: header ? FontWeight.w800 : FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          for (final value in values)
            SizedBox(
              width: 52,
              child: Text(value, textAlign: TextAlign.end, style: style),
            ),
        ],
      ),
    );
  }
}
