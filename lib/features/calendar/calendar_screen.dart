import 'package:finora/app/theme.dart';
import 'package:finora/application/calendar.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/calendar.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

IconData calendarIcon(CalendarEventKind kind) => switch (kind) {
  CalendarEventKind.healthInsuranceSwitch => Icons.health_and_safety_outlined,
  CalendarEventKind.pillar3aDeposit => Icons.savings_outlined,
  CalendarEventKind.taxReturn => Icons.receipt_long_outlined,
  CalendarEventKind.bill => Icons.event_repeat,
  CalendarEventKind.goalDeadline => Icons.flag_outlined,
  CalendarEventKind.assetReview => Icons.home_work_outlined,
  CalendarEventKind.plusRenewal => Icons.auto_awesome,
};

/// One event row: icon, title, detail and how many days are left.
class CalendarEventTile extends StatelessWidget {
  const CalendarEventTile({required this.event, required this.now, super.key});
  final CalendarEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = event.daysFrom(now);
    final urgent = days <= 7 && event.kind != CalendarEventKind.bill;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: urgent ? const Color(0xFFFFF1D6) : finoraSoftBlue,
        foregroundColor: urgent ? finoraWarning : finoraBlueText,
        child: Icon(calendarIcon(event.kind), size: 20),
      ),
      title: Text(
        l10n.calendarTitle(event),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(l10n.calendarDetail(event)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat.MMMd(l10n.localeName).format(event.date),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            l10n.inDays(days),
            style: TextStyle(
              fontSize: 12,
              color: urgent ? finoraWarning : finoraMutedInk,
            ),
          ),
        ],
      ),
      onTap: () => context.push(event.route),
    );
  }
}

/// Dashboard section with the next few dated events.
class UpcomingEventsSection extends ConsumerWidget {
  const UpcomingEventsSection({super.key});

  /// Only events this close make it to the dashboard.
  static const window = 45;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(clockProvider)();
    final events = (ref.watch(calendarProvider).value ?? const [])
        .where((event) => event.daysFrom(now) <= window)
        .take(3)
        .toList();
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          l10n.comingUpSection,
          action: TextButton(
            onPressed: () => context.push('/calendar'),
            child: Text(l10n.seeAll),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < events.length; index++) ...[
                CalendarEventTile(event: events[index], now: now),
                if (index != events.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Twelve months of deadlines, bills, goals and reviews, grouped by month.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(clockProvider)();
    final calendar = ref.watch(calendarProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.calendarScreenTitle),
        actions: [
          IconButton(
            tooltip: l10n.calendarExport,
            icon: const Icon(Icons.ios_share),
            onPressed: calendar.value == null
                ? null
                : () => _export(context, calendar.value!, now),
          ),
        ],
      ),
      body: FinoraPage(
        child: calendar.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.overviewUnavailable)),
          data: (events) {
            final byMonth = <DateTime, List<CalendarEvent>>{};
            for (final event in events) {
              byMonth
                  .putIfAbsent(
                    DateTime(event.date.year, event.date.month),
                    () => [],
                  )
                  .add(event);
            }
            return ListView(
              children: [
                Text(
                  l10n.calendarIntro,
                  style: const TextStyle(color: finoraMutedInk, height: 1.4),
                ),
                for (final entry in byMonth.entries) ...[
                  SectionTitle(formatMonthYear(entry.key)),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < entry.value.length; i++) ...[
                          CalendarEventTile(event: entry.value[i], now: now),
                          if (i != entry.value.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _export(context, events, now),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(l10n.calendarExport),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.calendarExportNote,
                  style: const TextStyle(color: finoraMutedInk, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    List<CalendarEvent> events,
    DateTime now,
  ) async {
    final l10n = context.l10n;
    final ics = FinancialCalendar.toIcs(
      events,
      title: l10n.calendarTitle,
      description: l10n.calendarDetail,
      now: now,
    );
    await Clipboard.setData(ClipboardData(text: ics));
    if (!context.mounted) return;
    final count = events.where((event) => event.kind.exportable).length;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.calendarCopied(count))));
  }
}
