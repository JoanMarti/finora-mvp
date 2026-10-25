import 'package:finora/app/bootstrap.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/application/backend.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/backend_services.dart';
import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/purchases.dart';
import 'package:finora/domain/reminders.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/calendar/calendar_screen.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class _FakeStore implements PurchaseService {
  _FakeStore({required this.buy, required this.restoreResult});
  final PurchaseResult buy;
  final PurchaseResult restoreResult;

  @override
  bool get isStore => true;

  @override
  Future<PurchaseResult> buyPlus() async => buy;

  @override
  Future<PurchaseResult> restore() async => restoreResult;
}

class _NoPermission implements NotificationPermissions {
  @override
  Future<bool> request() async => false;
}

class _RecordingReminders implements ReminderService {
  final calls = <List<CalendarEvent>>[];

  @override
  Future<void> syncReminders(
    String installationId,
    List<CalendarEvent> events, {
    required String languageCode,
  }) async => calls.add(events);
}

Widget _screen(Widget child, {List<Override> extra = const []}) => ProviderScope(
  overrides: [...testOverrides(), ...extra],
  child: MaterialApp(
    theme: buildFinoraTheme(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

UserSession _session(WidgetTester tester, Type screen) =>
    ProviderScope.containerOf(
      tester.element(find.byType(screen)),
    ).read(sessionProvider);

CalendarEvent _event(CalendarEventKind kind) =>
    CalendarEvent(kind: kind, date: DateTime(2026, 11, 30), route: '/');

void main() {
  group('Reminder preferences', () {
    final events = [
      _event(CalendarEventKind.healthInsuranceSwitch),
      _event(CalendarEventKind.taxReturn),
      _event(CalendarEventKind.bill),
    ];

    test('nothing is sent until the user opts in', () {
      expect(const ReminderPreferences().filter(events), isEmpty);
      expect(
        const ReminderPreferences(enabled: false).filter(events),
        isEmpty,
      );
    });

    test('muted kinds and bills are left out', () {
      const prefs = ReminderPreferences(
        enabled: true,
        muted: {CalendarEventKind.taxReturn},
      );
      expect(prefs.filter(events).map((event) => event.kind), [
        CalendarEventKind.healthInsuranceSwitch,
      ]);
      final restored = ReminderPreferences.fromJson(prefs.toJson());
      expect(restored.enabled, isTrue);
      expect(restored.muted, {CalendarEventKind.taxReturn});
      expect(ReminderPreferences.kinds, isNot(contains(CalendarEventKind.bill)));
    });

    test('the backend only gets what the user wants', () async {
      final recorder = _RecordingReminders();
      final container = ProviderContainer(
        overrides: [
          ...demoOverrides(
            sessionStore: InMemorySessionStore(UserSession.demo()),
          ),
          clockProvider.overrideWithValue(() => testNow),
          backendEnabledProvider.overrideWithValue(true),
          reminderServiceProvider.overrideWithValue(recorder),
        ],
      );
      addTearDown(container.dispose);
      container.read(backendSyncProvider);
      await container.read(overviewProvider.future);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(recorder.calls, isNotEmpty);
      expect(recorder.calls.last, isEmpty);

      container
          .read(sessionProvider.notifier)
          .setReminders(const ReminderPreferences(enabled: true));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        recorder.calls.last.map((event) => event.kind),
        contains(CalendarEventKind.healthInsuranceSwitch),
      );
    });
  });

  group('Plus purchase', () {
    testWidgets('a failed store purchase keeps the free plan', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        _screen(
          const PlusScreen(),
          extra: [
            purchaseServiceProvider.overrideWithValue(
              _FakeStore(
                buy: const PurchaseResult(PurchaseStatus.failed),
                restoreResult: const PurchaseResult(
                  PurchaseStatus.nothingToRestore,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('App Store or Google Play'), findsOneWidget);

      final start = find.textContaining('Start Plus ·');
      await tester.scrollUntilVisible(
        start,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(start);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start Plus'));
      await tester.pumpAndSettle();
      expect(_session(tester, PlusScreen).isPlus, isFalse);
      expect(find.textContaining('did not go through'), findsOneWidget);
    });

    testWidgets('restoring unlocks Plus with the store start date', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final since = DateTime(2026, 3, 1);
      await tester.pumpWidget(
        _screen(
          const PlusScreen(),
          extra: [
            purchaseServiceProvider.overrideWithValue(
              _FakeStore(
                buy: const PurchaseResult(PurchaseStatus.cancelled),
                restoreResult: PurchaseResult(
                  PurchaseStatus.restored,
                  since: since,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final restore = find.text('Restore purchase');
      await tester.scrollUntilVisible(
        restore,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(restore);
      await tester.pumpAndSettle();
      final session = _session(tester, PlusScreen);
      expect(session.isPlus, isTrue);
      expect(session.plusSince, since);
      expect(find.text('Your Finora Plus subscription was restored.'), findsOneWidget);
    });
  });

  group('Calendar reminders', () {
    testWidgets('turning reminders on asks for permission', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(_screen(const CalendarScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn on reminders'));
      await tester.pumpAndSettle();
      expect(_session(tester, CalendarScreen).reminders.enabled, isTrue);
      expect(find.text('Reminders on'), findsOneWidget);

      await tester.tap(find.text('Reminders on'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Tax return'));
      await tester.pumpAndSettle();
      expect(
        _session(tester, CalendarScreen).reminders.muted,
        {CalendarEventKind.taxReturn},
      );
    });

    testWidgets('blocked notifications keep reminders off', (tester) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        _screen(
          const CalendarScreen(),
          extra: [
            notificationPermissionsProvider.overrideWithValue(_NoPermission()),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn on reminders'));
      await tester.pumpAndSettle();
      expect(_session(tester, CalendarScreen).reminders.enabled, isFalse);
      expect(find.textContaining('Notifications are blocked'), findsOneWidget);
    });
  });
}
