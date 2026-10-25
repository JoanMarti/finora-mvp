import 'package:finora/app/theme.dart';
import 'package:finora/application/backend.dart';
import 'package:finora/application/calendar.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/reminders.dart';
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
                const SizedBox(height: 12),
                const _RemindersCard(),
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

/// Asks once whether to send push reminders, then lets the user choose
/// which kinds of dates they want.
class _RemindersCard extends ConsumerWidget {
  const _RemindersCard();

  Future<void> _turnOn(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final allowed = await ref.read(notificationPermissionsProvider).request();
    final session = ref.read(sessionProvider.notifier);
    final current = ref.read(sessionProvider).reminders;
    if (!allowed) {
      session.setReminders(current.copyWith(enabled: false));
      messenger.showSnackBar(SnackBar(content: Text(l10n.remindersBlocked)));
      return;
    }
    session.setReminders(current.copyWith(enabled: true));
    messenger.showSnackBar(SnackBar(content: Text(l10n.remindersOn)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reminders = ref.watch(
      sessionProvider.select((session) => session.reminders),
    );
    final session = ref.read(sessionProvider.notifier);
    return switch (reminders.enabled) {
      null => Card(
        color: finoraSoftBlue,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.remindersAskTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(l10n.remindersAskBody, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 10),
              Row(
                children: [
                  // The theme makes filled buttons full width.
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _turnOn(context, ref),
                      child: Text(l10n.remindersTurnOn),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => session.setReminders(
                      reminders.copyWith(enabled: false),
                    ),
                    child: Text(l10n.offersConsentDecline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      true => Card(
        child: ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(l10n.remindersOnTitle),
          subtitle: Text(l10n.remindersOnBody),
          trailing: const Icon(Icons.tune),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => const _ReminderSettings(),
          ),
        ),
      ),
      false => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _turnOn(context, ref),
          icon: const Icon(Icons.notifications_none),
          label: Text(l10n.remindersTurnOn),
        ),
      ),
    };
  }
}

class _ReminderSettings extends ConsumerWidget {
  const _ReminderSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reminders = ref.watch(
      sessionProvider.select((session) => session.reminders),
    );
    final session = ref.read(sessionProvider.notifier);
    String label(CalendarEventKind kind) => switch (kind) {
      CalendarEventKind.healthInsuranceSwitch => l10n.reminderHealth,
      CalendarEventKind.pillar3aDeposit => l10n.reminderPillar,
      CalendarEventKind.taxReturn => l10n.reminderTax,
      CalendarEventKind.goalDeadline => l10n.reminderGoals,
      CalendarEventKind.assetReview => l10n.reminderAssets,
      CalendarEventKind.plusRenewal => l10n.reminderPlus,
      CalendarEventKind.bill => '',
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.remindersSettingsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final kind in ReminderPreferences.kinds)
              SwitchListTile(
                value: !reminders.muted.contains(kind),
                title: Text(label(kind)),
                onChanged: (on) => session.setReminders(
                  reminders.copyWith(
                    muted: on
                        ? ({...reminders.muted}..remove(kind))
                        : {...reminders.muted, kind},
                  ),
                ),
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: finoraDanger),
              onPressed: () {
                session.setReminders(reminders.copyWith(enabled: false));
                Navigator.pop(context);
              },
              child: Text(l10n.remindersTurnOff),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.remindersPrivacy,
                style: const TextStyle(color: finoraMutedInk, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
