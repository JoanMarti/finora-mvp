import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/overview/widgets/balance_overview_card.dart';
import 'package:finora/features/overview/widgets/insights_carousel.dart';
import 'package:finora/features/overview/widgets/wealth_plan_card.dart';
import 'package:finora/features/overview/widgets/wealth_trajectory_card.dart';
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
                  error: (_, _) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Your overview is temporarily unavailable.'),
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
                  if (overviewValue.history.length >= 2) ...[
                    const SizedBox(height: 12),
                    WealthTrajectoryCard(overview: overviewValue),
                  ],
                  const SizedBox(height: 24),
                  const SectionTitle('Your wealth plan'),
                  WealthPlanCard(
                    overview: overviewValue,
                    targets: ref.watch(wealthTargetsProvider),
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle('Ideas for you'),
                  PersonalizedInsightsCarousel(
                    insights: buildInsights(
                      overviewValue,
                      ref.watch(wealthTargetsProvider),
                      ref.watch(marketThemesProvider).value ?? const [],
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'finora',
                style: TextStyle(
                  color: finoraBlue,
                  fontSize: 23,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your wealth at a glance',
                style: TextStyle(color: finoraMutedInk, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: alerts.isEmpty
              ? 'Notifications'
              : 'Notifications, ${alerts.length} new',
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
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Notifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            if (alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "You're all caught up. Connections are healthy and no bills are due this week.",
                  style: TextStyle(color: finoraMutedInk, height: 1.4),
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
                          alert.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(alert.description),
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
    ),
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
            const Text(
              'No accounts connected yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Connect a bank, investment or Pillar 3a provider to see your net worth here.',
              style: TextStyle(color: finoraMutedInk, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/connect'),
              icon: const Icon(Icons.add),
              label: const Text('Add an institution'),
            ),
          ],
        ),
      ),
    );
  }
}
