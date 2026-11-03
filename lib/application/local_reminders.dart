import 'dart:async';

import 'package:finora/app/router.dart';
import 'package:finora/application/calendar.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/local_reminders.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Local notifications on this device; none on the web and in tests.
final localReminderSchedulerProvider = Provider<LocalReminderScheduler>(
  (ref) => const NoLocalReminders(),
);

/// The language reminders are written in: the app's, else the device's
/// when Finora speaks it, else English.
String reminderLanguage(String? chosen) {
  final code = chosen ?? Intl.getCurrentLocale().split(RegExp('[_-]')).first;
  return finoraLanguages.containsKey(code) ? code : 'en';
}

/// Reminders for what the user opted into, a week ahead, rescheduled
/// whenever the calendar, the choices or the language change. `FinoraApp`
/// keeps this provider alive.
final localReminderSyncProvider = Provider<void>((ref) {
  final scheduler = ref.watch(localReminderSchedulerProvider);
  if (scheduler is NoLocalReminders) return;

  void schedule(List<CalendarEvent> events) {
    final session = ref.read(sessionProvider);
    final language = reminderLanguage(session.languageCode);
    final l10n = lookupAppLocalizations(Locale(language));
    String date(DateTime value) {
      try {
        return DateFormat.yMMMMd(language).format(value);
      } on Object {
        return '${value.day}.${value.month}.${value.year}';
      }
    }

    final reminders = LocalReminderPlan.plan(
      events,
      session.reminders,
      now: ref.read(clockProvider)(),
      title: l10n.calendarTitle,
      body: (event) => '${date(event.date)} · ${l10n.calendarDetail(event)}',
    );
    unawaited(
      scheduler.replaceAll(reminders).catchError((Object _) {
        // Notifications turned off in the system: nothing to schedule.
      }),
    );
  }

  ref
    ..listen(calendarProvider, (_, next) {
      final events = next.value;
      if (events != null) schedule(events);
    }, fireImmediately: true)
    ..listen(
      sessionProvider.select(
        (session) => (session.reminders, session.languageCode),
      ),
      (_, _) {
        final events = ref.read(calendarProvider).value;
        if (events != null) schedule(events);
      },
    );
});

/// Opens the page of a reminder the user tapped.
final reminderNavigationProvider = Provider<void>((ref) {
  final scheduler = ref.watch(localReminderSchedulerProvider);
  if (scheduler is NoLocalReminders) return;
  final subscription = scheduler.openedRoutes.listen(
    (route) => ref.read(routerProvider).push(route),
  );
  ref.onDispose(subscription.cancel);
});
