import 'package:finora/app/theme.dart';
import 'package:finora/application/backend.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/purchases.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Plans: Free and Finora Premium side by side, what each includes, what
/// is coming to Premium, and the (demo) trial and purchase.
class PlusScreen extends ConsumerStatefulWidget {
  const PlusScreen({super.key});

  @override
  ConsumerState<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends ConsumerState<PlusScreen> {
  BillingPeriod _period = BillingPeriod.yearly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPremium = ref.watch(isPlusProvider);
    final trialUsed = ref.watch(sessionProvider.select((s) => s.trialUsed));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.plusTitle),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          return FinoraPage(
            maxWidth: wide ? 960 : 720,
            child: ListView(
              children: [
                Text(
                  l10n.plusHeadline,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.plusSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                if (isPremium) ...[
                  _StatusCard(onCancel: () => _confirmCancel(context)),
                  const SizedBox(height: 16),
                ],
                BillingToggle(
                  period: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: 14),
                PlanCards(
                  period: _period,
                  wide: wide,
                  storePrice: ref.watch(storePricesProvider).value?[_period],
                  currentIsPremium: isPremium,
                  freeAction: null,
                  premiumAction: isPremium
                      ? null
                      : (
                          label: trialUsed
                              ? l10n.subscribeAction(_priceLabel(l10n))
                              : l10n.trialStart(PlusPricing.trialDays),
                          onPressed: trialUsed
                              ? () => _confirmSubscribe(context)
                              : () => _startTrial(context),
                        ),
                  premiumFootnote: isPremium || trialUsed
                      ? null
                      : l10n.trialTerms(PlusPricing.trialReminderDays),
                ),
                if (!isPremium && !trialUsed)
                  Align(
                    child: TextButton(
                      onPressed: () => _confirmSubscribe(context),
                      child: Text(l10n.subscribeAction(_priceLabel(l10n))),
                    ),
                  ),
                SectionTitle(l10n.compareSection),
                const PlanComparisonTable(),
                SectionTitle(l10n.roadmapSection),
                const _RoadmapCard(),
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
                const SizedBox(height: 12),
                if (!isPremium)
                  TextButton(
                    onPressed: () => _restore(context),
                    child: Text(l10n.plusRestore),
                  ),
                Text(
                  ref.watch(purchaseServiceProvider).isStore
                      ? l10n.plusStoreNote
                      : l10n.plusDemoNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: finoraMutedInk, fontSize: 11),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  String _priceLabel(AppLocalizations l10n) => premiumPriceLabel(
    l10n,
    _period,
    ref.read(storePricesProvider).value?[_period],
  );

  void _startTrial(BuildContext context) =>
      startPremiumTrial(context, ref, period: _period);

  Future<void> _confirmSubscribe(BuildContext context) async {
    final period = _period;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.plusConfirmTitle),
        content: Text(
          ref.read(purchaseServiceProvider).isStore
              ? dialogContext.l10n.plusConfirmBodyStore(
                  _priceLabel(dialogContext.l10n),
                )
              : dialogContext.l10n.plusConfirmBody,
        ),
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
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await ref
        .read(purchaseServiceProvider)
        .buyPlus(period: period);
    if (!result.isActive) {
      if (result.status == PurchaseStatus.failed) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.plusPurchaseFailed)));
      }
      return;
    }
    ref
        .read(sessionProvider.notifier)
        .startPlus(since: result.since, period: period);
    messenger.showSnackBar(SnackBar(content: Text(l10n.plusWelcome)));
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await ref.read(purchaseServiceProvider).restore();
    if (result.isActive) {
      ref.read(sessionProvider.notifier).startPlus(since: result.since);
      messenger.showSnackBar(SnackBar(content: Text(l10n.plusRestored)));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.plusNothingToRestore)));
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
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

/// Monthly or yearly billing, with the yearly saving.
class BillingToggle extends StatelessWidget {
  const BillingToggle({
    required this.period,
    required this.onChanged,
    super.key,
  });

  final BillingPeriod period;
  final ValueChanged<BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SegmentedButton<BillingPeriod>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: BillingPeriod.monthly,
            label: Text(l10n.billingMonthly),
          ),
          ButtonSegment(
            value: BillingPeriod.yearly,
            label: Text(
              '${l10n.billingYearly} · '
              '${l10n.billingSave(PlusPricing.yearlySavingPercent)}',
            ),
          ),
        ],
        selected: {period},
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

typedef PlanAction = ({String label, VoidCallback onPressed});

/// Free and Premium as two cards: side by side on wide screens.
class PlanCards extends StatelessWidget {
  const PlanCards({
    required this.period,
    required this.wide,
    required this.currentIsPremium,
    required this.freeAction,
    required this.premiumAction,
    this.premiumFootnote,
    this.storePrice,
    super.key,
  });

  /// The store's own price for [period], shown instead of the reference
  /// price on store builds.
  final StorePrice? storePrice;
  final BillingPeriod period;
  final bool wide;
  final bool currentIsPremium;
  final PlanAction? freeAction;
  final PlanAction? premiumAction;
  final String? premiumFootnote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final free = _PlanCard(
      name: l10n.planFreeName,
      tagline: l10n.planFreeTagline,
      price: l10n.planFreePrice,
      priceNote: l10n.planForever,
      current: !currentIsPremium,
      highlights: [
        '${l10n.featureBanks}: ${l10n.limitUpTo(FreeLimits.institutions)}',
        '${l10n.featureHistory}: ${l10n.limitMonths(FreeLimits.historyMonths)}',
        '${l10n.featureGoals}: ${l10n.limitUpTo(FreeLimits.goals)}',
        l10n.featureAnalysis,
        l10n.featureHints,
        l10n.featureCalendar,
      ],
      action: freeAction,
      primary: false,
      fillHeight: wide,
    );
    final yearly = period == BillingPeriod.yearly;
    final store = storePrice;
    final premium = _PlanCard(
      name: l10n.plusTitle,
      tagline: l10n.planPremiumTagline,
      price: store != null
          ? store.formattedPrice
          : yearly
          ? formatMoney(PlusPricing.yearlyPerMonth)
          : formatMoney(PlusPricing.monthly),
      priceNote: store != null
          ? (yearly ? l10n.billingYearly : l10n.billingMonthly)
          : yearly
          ? l10n.planYearlyEquivalent(formatMoneyWhole(PlusPricing.yearly))
          : l10n.planBilledMonthly,
      current: currentIsPremium,
      recommended: !currentIsPremium,
      highlights: [
        '${l10n.featureBanks}: ${l10n.limitUnlimited}',
        '${l10n.featureHistory}: '
            '${l10n.limitMonths(FreeLimits.premiumHistoryMonths)}',
        '${l10n.featureGoals}: ${l10n.limitUnlimited}',
        l10n.featureScenarios,
        l10n.featureHousehold,
        l10n.featureTaxExport,
      ],
      action: premiumAction,
      footnote: premiumFootnote,
      primary: true,
      fillHeight: wide,
    );
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: free),
            const SizedBox(width: 14),
            Expanded(child: premium),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [premium, const SizedBox(height: 12), free],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.tagline,
    required this.price,
    required this.priceNote,
    required this.current,
    required this.highlights,
    required this.action,
    required this.primary,
    required this.fillHeight,
    this.recommended = false,
    this.footnote,
  });

  final String name;
  final String tagline;
  final String price;
  final String priceNote;
  final bool current;
  final bool recommended;
  final List<String> highlights;
  final PlanAction? action;
  final bool primary;

  /// Side by side, both cards share a height and the buttons line up.
  final bool fillHeight;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final action = this.action;
    final footnote = this.footnote;
    return Container(
      decoration: BoxDecoration(
        color: finoraWhite,
        borderRadius: BorderRadius.circular(finoraRadius),
        border: Border.all(
          color: primary ? finoraBlue : finoraBorder,
          width: primary ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: finoraInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (current)
                ValuePill(label: l10n.planCurrent, color: finoraGreen)
              else if (recommended)
                ValuePill(label: l10n.planRecommended, color: finoraBlue),
            ],
          ),
          const SizedBox(height: 4),
          Text(tagline, style: const TextStyle(color: finoraMutedInk)),
          const SizedBox(height: 14),
          Text(
            price,
            style: const TextStyle(
              color: finoraInk,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
              fontFeatures: finoraTabular,
            ),
          ),
          Text(
            priceNote,
            style: const TextStyle(color: finoraMutedInk, fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (final line in highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check,
                    size: 18,
                    color: primary ? finoraBlueText : finoraGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(line, style: const TextStyle(height: 1.35)),
                  ),
                ],
              ),
            ),
          if (fillHeight) const Spacer(),
          if (action != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: primary
                  ? FilledButton(
                      onPressed: action.onPressed,
                      child: Text(action.label, textAlign: TextAlign.center),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 50),
                      ),
                      onPressed: action.onPressed,
                      child: Text(action.label, textAlign: TextAlign.center),
                    ),
            ),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 8),
            Text(
              footnote,
              style: const TextStyle(
                color: finoraMutedInk,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Feature by feature: what Free and Premium include.
class PlanComparisonTable extends StatelessWidget {
  const PlanComparisonTable({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // '' = included, null = not included, other text = the limit.
    final rows = <(String, String?, String?)>[
      (
        l10n.featureBanks,
        l10n.limitUpTo(FreeLimits.institutions),
        l10n.limitUnlimited,
      ),
      (
        l10n.featureHistory,
        l10n.limitMonths(FreeLimits.historyMonths),
        l10n.limitMonths(FreeLimits.premiumHistoryMonths),
      ),
      (
        l10n.featureGoals,
        l10n.limitUpTo(FreeLimits.goals),
        l10n.limitUnlimited,
      ),
      (l10n.featureAnalysis, '', ''),
      (l10n.featureHints, '', ''),
      (l10n.featureCalendar, '', ''),
      (l10n.featureSimulators, '', ''),
      (l10n.featureScenarios, null, ''),
      (l10n.featureHousehold, null, ''),
      (l10n.featureTaxExport, null, ''),
    ];
    Widget cell(String? value) {
      if (value == null) {
        return const Icon(Icons.remove, size: 18, color: finoraSlate);
      }
      if (value.isEmpty) {
        return const Icon(Icons.check, size: 18, color: finoraGreen);
      }
      return Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: finoraInk,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    const header = TextStyle(
      color: finoraSlate,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
    );
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.compareFeature.toUpperCase(), style: header),
                ),
                SizedBox(
                  width: 86,
                  child: Text(
                    l10n.planFreeName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: header,
                  ),
                ),
                SizedBox(
                  width: 86,
                  child: Text(
                    l10n.plusBadge.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: header.copyWith(color: finoraBlueText),
                  ),
                ),
              ],
            ),
          ),
          for (final (label, free, premium) in rows) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(width: 86, child: Center(child: cell(free))),
                  SizedBox(width: 86, child: Center(child: cell(premium))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (
        Icons.notifications_active_outlined,
        l10n.roadmapAlertsTitle,
        l10n.roadmapAlertsBody,
      ),
      (Icons.folder_outlined, l10n.roadmapVaultTitle, l10n.roadmapVaultBody),
      (
        Icons.picture_as_pdf_outlined,
        l10n.roadmapReportTitle,
        l10n.roadmapReportBody,
      ),
      (Icons.forum_outlined, l10n.roadmapCoachTitle, l10n.roadmapCoachBody),
      (
        Icons.support_agent,
        l10n.roadmapSupportTitle,
        l10n.roadmapSupportBody,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.roadmapBody,
                style: const TextStyle(color: finoraMutedInk),
              ),
            ),
            for (final (icon, title, body) in items)
              ListTile(
                leading: TonalIcon(icon, size: 40),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(body),
                trailing: ValuePill(label: l10n.comingSoon, color: finoraSlate),
              ),
          ],
        ),
      ),
    );
  }
}

/// Active plan: subscription start, or trial end with days left.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider);
    final now = ref.watch(clockProvider)();
    final format = DateFormat.yMMMd(l10n.localeName);
    final trialEnd = session.onTrial ? session.trialEndsAt : null;
    final since = session.plusSince;
    return Card(
      color: finoraSoftBlue,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  trialEnd == null ? Icons.verified : Icons.hourglass_bottom,
                  color: trialEnd == null ? finoraGreen : finoraBlueText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trialEnd == null
                        ? l10n.plusActive
                        : l10n.trialActive(format.format(trialEnd)),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                trialEnd != null
                    ? l10n.trialDaysLeft(daysLeft(now, trialEnd))
                    : since == null
                    ? ''
                    : l10n.plusActiveSince(format.format(since)),
                style: const TextStyle(color: finoraMutedInk),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: Text(
                  trialEnd == null ? l10n.plusCancel : l10n.trialEndNow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whole days until [end], counting a started day as one.
int daysLeft(DateTime now, DateTime end) {
  final hours = end.difference(now).inHours;
  return hours <= 0 ? 0 : (hours + 23) ~/ 24;
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

/// Why the paywall opened.
enum PaywallReason { banks, goals }

/// Explains a free-plan limit and offers the trial or the plans screen.
Future<void> showPaywall(BuildContext context, PaywallReason reason) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _Paywall(reason: reason),
  );
}

class _Paywall extends ConsumerWidget {
  const _Paywall({required this.reason});
  final PaywallReason reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trialUsed = ref.watch(sessionProvider.select((s) => s.trialUsed));
    final (icon, title, body) = switch (reason) {
      PaywallReason.banks => (
        Icons.account_balance_outlined,
        l10n.paywallBanksTitle(FreeLimits.institutions),
        l10n.paywallBanksBody(FreeLimits.institutions),
      ),
      PaywallReason.goals => (
        Icons.flag_outlined,
        l10n.paywallGoalsTitle(FreeLimits.goals),
        l10n.paywallGoalsBody(FreeLimits.goals),
      ),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TonalIcon(icon, size: 48),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: finoraBlueText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.plusTeaser,
                    style: const TextStyle(color: finoraMutedInk, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!trialUsed) ...[
              FilledButton(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  final outer = navigator.context;
                  navigator.pop();
                  startPremiumTrial(outer, ref);
                },
                child: Text(l10n.trialStart(PlusPricing.trialDays)),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 50)),
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.push('/plus');
              },
              child: Text(l10n.paywallSeePlans),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.paywallNotNow),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shown where a Premium feature would be, with a way to
/// unlock it.
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

/// Price of Premium for [period]: the store's price when there is one,
/// otherwise the reference price.
String premiumPriceLabel(
  AppLocalizations l10n,
  BillingPeriod period,
  StorePrice? store,
) {
  final yearly = period == BillingPeriod.yearly;
  if (store != null) {
    return yearly
        ? l10n.planPerYear(store.formattedPrice)
        : l10n.planPerMonth(store.formattedPrice);
  }
  return yearly
      ? l10n.planPerYear(formatMoneyWhole(PlusPricing.yearly))
      : l10n.planPerMonth(formatMoney(PlusPricing.monthly));
}

/// Starts the free Premium trial. The demo starts it in the app; a store
/// build subscribes through Google Play with the free-trial offer, so the
/// store reminds and bills (or not) at the end.
Future<void> startPremiumTrial(
  BuildContext context,
  WidgetRef ref, {
  BillingPeriod period = BillingPeriod.yearly,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final service = ref.read(purchaseServiceProvider);
  final session = ref.read(sessionProvider.notifier);
  if (!service.isStore) {
    session.startTrial();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.trialStarted(PlusPricing.trialDays))),
    );
    return;
  }
  final result = await service.buyPlus(period: period, withTrial: true);
  if (result.isActive) {
    session.startPlus(since: result.since, period: period);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.trialStarted(PlusPricing.trialDays))),
    );
  } else if (result.status == PurchaseStatus.failed) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.plusPurchaseFailed)));
  }
}
