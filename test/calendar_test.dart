import 'package:finora/app/theme.dart';
import 'package:finora/application/calendar.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/features/calendar/calendar_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

RecurringPayment _bill(String merchant, BillCategory category, DateTime due) =>
    RecurringPayment(
      merchant: merchant,
      category: category,
      amount: const Money.cents(-34820),
      cadence: BillCadence.monthly,
      nextDueAt: due,
    );

CalendarInput _input({DateTime? now, DateTime? plusSince}) => CalendarInput(
  now: now ?? testNow,
  bills: [
    _bill('CSS Insurance', BillCategory.healthInsurance, DateTime(2026, 11, 1)),
    _bill('Netflix', BillCategory.streaming, DateTime(2027, 1, 15)),
  ],
  goals: [
    SavingsGoal(
      id: 'car',
      name: 'Car',
      target: const Money.cents(2000000),
      deadline: DateTime(2027, 6, 30),
    ),
    SavingsGoal(
      id: 'flat',
      name: 'Flat deposit',
      target: const Money.cents(4000000),
      deadline: DateTime(2028, 6),
    ),
  ],
  assets: [
    ManualAsset(
      id: 'btc',
      kind: ManualAssetKind.crypto,
      name: 'Bitcoin',
      value: const Money.cents(500000),
      valuedAt: testNow.subtract(const Duration(days: 60)),
    ),
  ],
  pillar3aPaid: const Money.cents(400000),
  pillar3aLimit: const Money.cents(725800),
  hasPillar3a: true,
  plusSince: plusSince,
);

void main() {
  group('Financial calendar', () {
    test('orders Swiss deadlines, bills, goals and reviews', () {
      final events = FinancialCalendar.of(
        _input(plusSince: DateTime(2026, 1, 10)),
      );
      expect(events.map((event) => event.kind).toList(), [
        CalendarEventKind.assetReview, // overdue → today
        CalendarEventKind.bill, // CSS on 1 November
        CalendarEventKind.healthInsuranceSwitch, // 30 November
        CalendarEventKind.pillar3aDeposit, // 31 December
        CalendarEventKind.plusRenewal, // 10 January
        CalendarEventKind.taxReturn, // 31 March
        CalendarEventKind.goalDeadline, // Car, June 2027
      ]);
      expect(events.first.daysFrom(testNow), 0);
      expect(events[3].amount, Money(3258));
      expect(events[5].date, DateTime(2027, 3, 31));
      // Netflix is beyond the bill window, the flat goal beyond a year.
      expect(events.map((event) => event.subject), isNot(contains('Netflix')));
      expect(
        events.map((event) => event.subject),
        isNot(contains('Flat deposit')),
      );
    });

    test('a passed deadline moves to next year', () {
      final events = FinancialCalendar.of(_input(now: DateTime(2026, 12, 5)));
      final health = events.firstWhere(
        (event) => event.kind == CalendarEventKind.healthInsuranceSwitch,
      );
      expect(health.date, DateTime(2027, 11, 30));
    });

    test('exports deadlines as an iCalendar file', () {
      final events = FinancialCalendar.of(_input());
      final ics = FinancialCalendar.toIcs(
        events,
        title: (event) => event.kind == CalendarEventKind.goalDeadline
            ? 'Goal: Car, new'
            : event.kind.name,
        description: (_) => 'Details',
        now: testNow,
      );
      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      final exportable = events.where((event) => event.kind.exportable).length;
      expect('BEGIN:VEVENT'.allMatches(ics).length, exportable);
      expect(ics, contains('DTSTART;VALUE=DATE:20261130'));
      expect(ics, contains(r'SUMMARY:Goal: Car\, new'));
      expect(ics, isNot(contains('SUMMARY:bill')));
      expect(ics, contains('TRIGGER:-P7D'));
    });

    test('the demo profile has its deadlines', () async {
      final container = createTestContainer();
      final events = await container.read(calendarProvider.future);
      final kinds = events.map((event) => event.kind);
      expect(kinds, contains(CalendarEventKind.healthInsuranceSwitch));
      expect(kinds, contains(CalendarEventKind.taxReturn));
      // The demo goal (June 2028) is beyond the twelve-month horizon.
      expect(kinds, isNot(contains(CalendarEventKind.goalDeadline)));
    });
  });

  testWidgets('calendar screen lists events and copies them', (tester) async {
    usePhoneViewport(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(),
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Financial calendar'), findsOneWidget);
    expect(find.text('Last day to switch health insurance'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to my calendar'));
    await tester.pumpAndSettle();
    expect(copied, contains('BEGIN:VCALENDAR'));
    expect(copied, contains('SUMMARY:Last day to switch health insurance'));
    expect(find.textContaining('copied as a calendar file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
