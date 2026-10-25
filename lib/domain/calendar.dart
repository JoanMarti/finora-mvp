import 'package:finora/domain/assets.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';

/// Kinds of dated events in the financial calendar.
enum CalendarEventKind {
  /// Cancellation of basic health insurance must reach the insurer by
  /// 30 November to switch on 1 January.
  healthInsuranceSwitch,

  /// Pillar 3a contributions count for the year they are credited in.
  pillar3aDeposit,

  /// Most cantons expect the tax return by 31 March; extensions are common.
  taxReturn,
  bill,
  goalDeadline,
  assetReview,
  plusRenewal,

  /// The free Premium trial ends: choose a plan or stay on Free.
  trialEnd;

  /// Deadlines and reviews are worth putting in the phone's calendar;
  /// bills change every month and stay in the app.
  bool get exportable => this != bill;
}

class CalendarEvent {
  const CalendarEvent({
    required this.kind,
    required this.date,
    required this.route,
    this.subject,
    this.amount,
  });

  final CalendarEventKind kind;
  final DateTime date;

  /// Where the user can act on the event.
  final String route;

  /// Merchant, goal or asset name, when the event is about one.
  final String? subject;
  final Money? amount;

  /// Stable id so a re-exported calendar updates instead of duplicating.
  String get id =>
      '${kind.name}-${subject ?? ''}-${date.year}${date.month}${date.day}'
          .replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');

  int daysFrom(DateTime now) => DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
}

/// What the calendar is built from; all of it is already in the app.
class CalendarInput {
  const CalendarInput({
    required this.now,
    required this.bills,
    required this.goals,
    required this.assets,
    required this.pillar3aPaid,
    required this.pillar3aLimit,
    required this.hasPillar3a,
    this.plusSince,
    this.trialEndsAt,
  });

  final DateTime now;
  final List<RecurringPayment> bills;
  final List<SavingsGoal> goals;
  final List<ManualAsset> assets;
  final Money pillar3aPaid;
  final Money pillar3aLimit;
  final bool hasPillar3a;
  final DateTime? plusSince;
  final DateTime? trialEndsAt;
}

abstract final class FinancialCalendar {
  /// How far ahead the calendar looks.
  static const horizon = Duration(days: 366);

  /// Bills are shown for the next month only.
  static const billWindow = Duration(days: 31);

  static List<CalendarEvent> of(CalendarInput input) {
    final now = input.now;
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(horizon);
    bool inWindow(DateTime date, [Duration? window]) =>
        !date.isBefore(today) &&
        !date.isAfter(window == null ? end : today.add(window));

    /// The next occurrence of a fixed day of the year, today included.
    DateTime next(int month, int day) {
      final thisYear = DateTime(now.year, month, day);
      return thisYear.isBefore(today) ? DateTime(now.year + 1, month, day) : thisYear;
    }

    final events = <CalendarEvent>[];

    final healthBill = input.bills
        .where((bill) => bill.category == BillCategory.healthInsurance)
        .firstOrNull;
    if (healthBill != null) {
      events.add(
        CalendarEvent(
          kind: CalendarEventKind.healthInsuranceSwitch,
          date: next(11, 30),
          subject: healthBill.merchant,
          route: '/offers',
        ),
      );
    }

    final room = input.pillar3aLimit - input.pillar3aPaid;
    if (input.hasPillar3a && room.cents > 0) {
      events.add(
        CalendarEvent(
          kind: CalendarEventKind.pillar3aDeposit,
          date: DateTime(now.year, 12, 31),
          amount: room,
          route: '/retirement',
        ),
      );
    }

    events.add(
      CalendarEvent(
        kind: CalendarEventKind.taxReturn,
        date: next(3, 31),
        route: '/tax',
      ),
    );

    for (final bill in input.bills) {
      if (!inWindow(bill.nextDueAt, billWindow)) continue;
      events.add(
        CalendarEvent(
          kind: CalendarEventKind.bill,
          date: bill.nextDueAt,
          subject: bill.merchant,
          amount: bill.amount.abs(),
          route: '/analysis',
        ),
      );
    }

    for (final goal in input.goals) {
      final deadline = goal.deadline;
      if (deadline == null) continue;
      events.add(
        CalendarEvent(
          kind: CalendarEventKind.goalDeadline,
          date: deadline,
          subject: goal.name,
          amount: goal.target,
          route: '/goals',
        ),
      );
    }

    for (final asset in input.assets) {
      final due = asset.valuedAt.add(asset.kind.reviewAfter);
      events.add(
        CalendarEvent(
          kind: CalendarEventKind.assetReview,
          // An overdue review is due today.
          date: due.isBefore(today) ? today : due,
          subject: asset.name,
          route: '/assets',
        ),
      );
    }

    final plusSince = input.plusSince;
    if (plusSince != null) {
      var renewal = DateTime(plusSince.year + 1, plusSince.month, plusSince.day);
      while (renewal.isBefore(today)) {
        renewal = DateTime(renewal.year + 1, renewal.month, renewal.day);
      }
      events.add(
        CalendarEvent(
          kind: CalendarEventKind.plusRenewal,
          date: renewal,
          route: '/plus',
        ),
      );
    }

    final trialEnd = input.trialEndsAt;
    if (trialEnd != null) {
      events.add(
        CalendarEvent(
          kind: CalendarEventKind.trialEnd,
          date: DateTime(trialEnd.year, trialEnd.month, trialEnd.day),
          route: '/plus',
        ),
      );
    }

    return events.where((event) => inWindow(event.date)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// An iCalendar file with the exportable events as all-day entries, so
  /// they can be added to the phone's calendar with their own reminders.
  static String toIcs(
    List<CalendarEvent> events, {
    required String Function(CalendarEvent) title,
    required String Function(CalendarEvent) description,
    required DateTime now,
  }) {
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
    String escape(String value) => value
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n');
    final stamp = '${date(now.toUtc())}T000000Z';
    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Finora//Financial calendar//EN',
      'CALSCALE:GREGORIAN',
      for (final event in events.where((event) => event.kind.exportable)) ...[
        'BEGIN:VEVENT',
        'UID:${event.id}@finora.ch',
        'DTSTAMP:$stamp',
        'DTSTART;VALUE=DATE:${date(event.date)}',
        'DTEND;VALUE=DATE:${date(event.date.add(const Duration(days: 1)))}',
        'SUMMARY:${escape(title(event))}',
        'DESCRIPTION:${escape(description(event))}',
        // Remind a week ahead: enough time to compare offers or pay in.
        'BEGIN:VALARM',
        'TRIGGER:-P7D',
        'ACTION:DISPLAY',
        'DESCRIPTION:${escape(title(event))}',
        'END:VALARM',
        'END:VEVENT',
      ],
      'END:VCALENDAR',
    ];
    // RFC 5545 asks for CRLF line endings.
    return '${lines.join('\r\n')}\r\n';
  }
}
