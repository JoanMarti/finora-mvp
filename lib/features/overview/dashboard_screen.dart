import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/calendar/calendar_screen.dart';
import 'package:finora/features/health/health_screen.dart';
import 'package:finora/features/offers/widgets/opportunity_widgets.dart';
import 'package:finora/features/overview/widgets/balance_overview_card.dart';
import 'package:finora/features/report/report_screen.dart';
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
                  const SizedBox(height: 16),
                  const _QuickActions(),
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
                  const MonthlyReportCard(),
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
    final session = ref.watch(sessionProvider);
    final alerts = ref.watch(alertsProvider).value ?? const <FinoraAlert>[];
    final hidden = session.hideAmounts;
    final hour = ref.watch(clockProvider)().hour;
    final l10n = context.l10n;
    final name = session.displayName ?? l10n.you;
    final greeting = hour < 12
        ? l10n.greetingMorning(name)
        : hour < 18
        ? l10n.greetingAfternoon(name)
        : l10n.greetingEvening(name);
    return Row(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.go('/profile'),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: finoraBrandGradient,
              shape: BoxShape.circle,
            ),
            child: Text(
              session.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: finoraInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.headerTagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: finoraMutedInk, fontSize: 13),
              ),
            ],
          ),
        ),
        _HeaderButton(
          tooltip: hidden ? l10n.showAmounts : l10n.hideAmounts,
          onPressed: () =>
              ref.read(sessionProvider.notifier).setHideAmounts(!hidden),
          child: Icon(
            hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: finoraInk,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
        _HeaderButton(
          tooltip: alerts.isEmpty
              ? l10n.notifications
              : l10n.notificationsNew(alerts.length),
          onPressed: () => _showAlerts(context, alerts),
          child: Badge(
            isLabelVisible: alerts.isNotEmpty,
            label: Text('${alerts.length}'),
            backgroundColor: finoraDanger,
            child: const Icon(
              Icons.notifications_none,
              color: finoraInk,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

/// Round white button used in the dashboard header.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: finoraWhite,
      fixedSize: const Size(44, 44),
      side: const BorderSide(color: finoraBorder),
    ),
    icon: child,
  );
}

/// Four shortcuts to what people open most.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = [
      (Icons.donut_small_outlined, l10n.quickAnalysis, '/analysis'),
      (Icons.pie_chart_outline, l10n.budgetsTitle, '/budgets'),
      (Icons.calendar_month_outlined, l10n.quickCalendar, '/calendar'),
      (Icons.savings_outlined, l10n.quickSave, '/offers'),
    ];
    return Row(
      children: [
        for (final (icon, label, route) in actions)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push(route),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: finoraWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: finoraBorder),
                      ),
                      child: Icon(icon, color: finoraBlueText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: finoraInk,
                      ),
                    ),
                  ],
                ),
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
    final household = ref.watch(
      sessionProvider.select((session) => session.household),
    );
    final tools = [
      (
        Icons.donut_small_outlined,
        l10n.analysisTitle,
        l10n.analysisToolSubtitle,
        '/analysis',
      ),
      (
        Icons.pie_chart_outline,
        l10n.budgetsTitle,
        l10n.budgetsToolSubtitle,
        '/budgets',
      ),
      (
        Icons.trending_down,
        l10n.debtsTitle,
        l10n.debtsToolSubtitle,
        '/debts',
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
        Icons.family_restroom,
        l10n.householdTitle,
        household == null
            ? l10n.householdToolSubtitle
            : l10n.householdToolWith(household.partnerName),
        '/household',
      ),
      (
        Icons.calculate_outlined,
        l10n.taxSavingsTitle,
        l10n.taxSavingsToolSubtitle,
        '/tax-savings',
      ),
      (
        Icons.house_outlined,
        l10n.homeTitle,
        l10n.homeToolSubtitle,
        '/home-buying',
      ),
      (
        Icons.receipt_long_outlined,
        l10n.taxTitle,
        l10n.taxToolSubtitle('$lastYear'),
        '/tax',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (icon, title, subtitle, route) in tools)
              SizedBox(
                width: width,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(route),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TonalIcon(icon, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: finoraMutedInk,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
