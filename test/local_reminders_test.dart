import 'package:finora/application/local_reminders.dart';
import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/local_reminders.dart';
import 'package:finora/domain/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 3, 10);

CalendarEvent _event(CalendarEventKind kind, DateTime date) =>
    CalendarEvent(kind: kind, date: date, route: '/${kind.name}');

List<ScheduledReminder> _plan(
  List<CalendarEvent> events, {
  ReminderPreferences preferences = const ReminderPreferences(enabled: true),
}) => LocalReminderPlan.plan(
  events,
  preferences,
  now: _now,
  title: (event) => event.kind.name,
  body: (event) => '${event.date.day}.${event.date.month}.',
);

void main() {
  test('reminds a week ahead at 9:00, soonest first', () {
    final reminders = _plan([
      _event(CalendarEventKind.pillar3aDeposit, DateTime(2026, 12, 31)),
      _event(CalendarEventKind.healthInsuranceSwitch, DateTime(2026, 11, 30)),
    ]);
    expect(reminders.map((item) => item.at), [
      DateTime(2026, 11, 23, 9),
      DateTime(2026, 12, 24, 9),
    ]);
    expect(reminders.first.title, 'healthInsuranceSwitch');
    expect(reminders.first.route, '/healthInsuranceSwitch');
    expect(reminders.map((item) => item.id), [1, 2]);
  });

  test('less than a week to go: tomorrow morning; past dates: none', () {
    final reminders = _plan([
      _event(CalendarEventKind.trialEnd, DateTime(2026, 11, 6)),
      _event(CalendarEventKind.taxReturn, DateTime(2026, 11, 3)),
    ]);
    expect(reminders.single.at, DateTime(2026, 11, 4, 9));
  });

  test('only what the user opted into', () {
    final events = [
      _event(CalendarEventKind.pillar3aDeposit, DateTime(2026, 12, 31)),
      _event(CalendarEventKind.bill, DateTime(2026, 12, 1)),
    ];
    expect(_plan(events, preferences: const ReminderPreferences()), isEmpty);
    expect(
      _plan(
        events,
        preferences: const ReminderPreferences(
          enabled: true,
          muted: {CalendarEventKind.pillar3aDeposit},
        ),
      ),
      isEmpty,
    );
    // Monthly bills stay in the app.
    expect(_plan(events).single.title, 'pillar3aDeposit');
  });

  test('reminders speak a language Finora knows', () {
    expect(reminderLanguage('de'), 'de');
    expect(reminderLanguage('es'), 'en');
  });
}
