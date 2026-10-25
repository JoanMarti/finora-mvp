import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/calendar/calendar_screen.dart';
import 'package:finora/features/health/health_screen.dart';
import 'package:finora/features/offers/widgets/opportunity_widgets.dart';
import 'package:finora/features/overview/widgets/balance_overview_card.dart';
import 'package:finora/features/overview/widgets/insights_carousel.dart';
import 'package:finora/features/overview/widgets/wealth_plan_card.dart';
import 'package:finora/features/overview/widgets/wealth_trajectory_card.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    final overviewValue = overview.value;
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => refreshFinancialData(ref),
          child: FinoraPage(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: ListView(
              children: [
                const _FinoraHeader(),
                const SizedBox(height: 18),
                overview.when(
                  loading: () => const SizedBox(
                    height: 218,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.overviewUnavailable),
                    ),
                  ),
                  data: (data) => data.isEmpty
                      ? const _EmptyOverview()
                      : BalanceOverviewCard(
                          overview: data,
                          onRefresh: () => refreshFinancialData(ref),
                        ),
                ),
                if (overviewValue != null && !overviewValue.isEmpty) ...[
                  const SizedBox(height: 12),
                  const HealthScoreCard(),
                  if (overviewValue.history.length >= 2) ...[
                    const SizedBox(height: 12),
                    WealthTrajectoryCard(overview: overviewValue),
                  ],
                  const SizedBox(height: 24),
                  SectionTitle(
                    l10n.wealthPlanSection,
                    action: TextButton(
                      onPressed: () => context.push('/goals'),
                      child: Text(l10n.editPlan),
                    ),
                  ),
                  WealthPlanCard(
                    overview: overviewValue,
                    targets: ref.watch(wealthTargetsProvider),
                    goals: ref.watch(goalProgressProvider).value ?? const [],
                  ),
                  const SizedBox(height: 12),
                  const SavingsOpportunitiesSection(),
                  const UpcomingEventsSection(),
                  const SizedBox(height: 12),
                  SectionTitle(l10n.planningToolsSection),
                  const _PlanningTools(),
                  const SizedBox(height: 24),
                  SectionTitle(l10n.ideasSection),
                  PersonalizedInsightsCarousel(
                    insights: buildInsights(
                      l10n,
                      overviewValue,
                      ref.watch(wealthTargetsProvider),
                      ref.watch(marketThemesProvider(languageCode)).value ??
                          const [],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const MarketDataNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinoraHeader extends ConsumerWidget {
  const _FinoraHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = ref.watch(sessionProvider).initials;
    final alerts = ref.watch(alertsProvider).value ?? const <FinoraAlert>[];
    final hidden = ref.watch(
      sessionProvider.select((session) => session.hideAmounts),
    );
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: finoraBlue,
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(
                color: Color(0x333C94FF),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'finora',
                style: TextStyle(
                  color: finoraBlue,
                  fontSize: 23,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.headerTagline,
                style: const TextStyle(color: finoraMutedInk, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: hidden ? context.l10n.showAmounts : context.l10n.hideAmounts,
          onPressed: () =>
              ref.read(sessionProvider.notifier).setHideAmounts(!hidden),
          icon: Icon(
            hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: finoraInk,
          ),
        ),
        IconButton(
          tooltip: alerts.isEmpty
              ? context.l10n.notifications
              : context.l10n.notificationsNew(alerts.length),
          onPressed: () => _showAlerts(context, alerts),
          icon: Badge(
            isLabelVisible: alerts.isNotEmpty,
            label: Text('${alerts.length}'),
            backgroundColor: finoraBlueText,
            child: const Icon(Icons.notifications_none, color: finoraInk),
          ),
        ),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.go('/profile'),
          child: CircleAvatar(
            radius: 19,
            backgroundColor: finoraSoftBlue,
            foregroundColor: finoraInk,
            child: Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

void _showAlerts(BuildContext context, List<FinoraAlert> alerts) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l10n.notifications,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  l10n.allCaughtUp,
                  style: const TextStyle(color: finoraMutedInk, height: 1.4),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final alert in alerts)
                      ListTile(
                        leading: Icon(
                          switch (alert.severity) {
                            AlertSeverity.critical => Icons.error,
                            AlertSeverity.warning => Icons.schedule,
                            AlertSeverity.info => Icons.event_outlined,
                          },
                          color: switch (alert.severity) {
                            AlertSeverity.critical => finoraDanger,
                            AlertSeverity.warning => finoraWarning,
                            AlertSeverity.info => finoraBlueText,
                          },
                        ),
                        title: Text(
                          l10n.alertTitle(alert),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(l10n.alertDescription(alert)),
                        trailing: alert.route == null
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: alert.route == null
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                context.push(alert.route!);
                              },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    },
  );
}

class _EmptyOverview extends StatelessWidget {
  const _EmptyOverview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.link_off, color: finoraSlate, size: 32),
            const SizedBox(height: 12),
            Text(
              context.l10n.noAccountsTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.noAccountsBody,
              style: const TextStyle(color: finoraMutedInk, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/connect'),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.addInstitutionTitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningTools extends ConsumerWidget {
  const _PlanningTools();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final goals = ref.watch(goalProgressProvider).value ?? const [];
    final projection = ref.watch(retirementProjectionProvider).value;
    final lastYear = ref.watch(clockProvider)().year - 1;
    final tools = [
      (
        Icons.donut_small_outlined,
        l10n.analysisTitle,
        l10n.analysisToolSubtitle,
        '/analysis',
      ),
      (
        Icons.calendar_month_outlined,
        l10n.calendarScreenTitle,
        l10n.calendarToolSubtitle,
        '/calendar',
      ),
      (
        Icons.flag_outlined,
        l10n.goalsTitle,
        goals.isEmpty ? l10n.setFirstGoal : l10n.goalCount(goals.length),
        '/goals',
      ),
      (
        Icons.beach_access_outlined,
        l10n.retirementTitle,
        projection == null
            ? l10n.retirementToolSubtitle
            : l10n.retirementToolEstimate(
                formatMoney(projection.totalMonthly),
                '${projection.retirementYear}',
              ),
        '/retirement',
      ),
      (
        Icons.receipt_long_outlined,
        l10n.taxTitle,
        l10n.taxToolSubtitle('$lastYear'),
        '/tax',
      ),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < tools.length; index++) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: finoraSoftBlue,
                foregroundColor: finoraBlueText,
                child: Icon(tools[index].$1, size: 20),
              ),
              title: Text(
                tools[index].$2,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(tools[index].$3),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(tools[index].$4),
            ),
            if (index != tools.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
