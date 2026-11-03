import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/reminders.dart';

/// A notification the device shows by itself at [at], without a server.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.route,
  });

  final int id;
  final String title;
  final String body;
  final DateTime at;

  /// Where tapping the notification leads.
  final String route;
}

/// Shows reminders as local notifications on this device.
abstract interface class LocalReminderScheduler {
  /// Replaces every reminder scheduled before with [reminders].
  Future<void> replaceAll(List<ScheduledReminder> reminders);

  /// Routes of the reminders the user tapped, including the one that
  /// opened the app.
  Stream<String> get openedRoutes;
}

/// Platforms without local notifications (web, tests).
class NoLocalReminders implements LocalReminderScheduler {
  const NoLocalReminders();

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {}

  @override
  Stream<String> get openedRoutes => const Stream.empty();
}

/// When to remind: a week before each date the user wants, at 9:00.
abstract final class LocalReminderPlan {
  static const leadDays = 7;
  static const hour = 9;

  /// Android keeps a limited number of alarms per app; Finora needs few.
  static const maxReminders = 40;

  static List<ScheduledReminder> plan(
    List<CalendarEvent> events,
    ReminderPreferences preferences, {
    required DateTime now,
    required String Function(CalendarEvent) title,
    required String Function(CalendarEvent) body,
  }) {
    final reminders = <ScheduledReminder>[];
    final sorted = [...preferences.filter(events)]
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final event in sorted) {
      final day = DateTime(event.date.year, event.date.month, event.date.day);
      var at = DateTime(day.year, day.month, day.day - leadDays, hour);
      if (at.isBefore(now)) {
        // Less than a week to go: remind tomorrow morning, if the date is
        // still ahead then.
        at = DateTime(now.year, now.month, now.day + 1, hour);
        if (at.isAfter(DateTime(day.year, day.month, day.day, 23, 59))) {
          continue;
        }
      }
      reminders.add(
        ScheduledReminder(
          id: reminders.length + 1,
          title: title(event),
          body: body(event),
          at: at,
          route: event.route,
        ),
      );
      if (reminders.length >= maxReminders) break;
    }
    return reminders;
  }
}
