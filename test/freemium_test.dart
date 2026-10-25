import 'package:finora/app/theme.dart';
import 'package:finora/application/calendar.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/connections/connection_screen.dart';
import 'package:finora/features/planning/goals_screen.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget screen, {
  UserSession? session,
}) async {
  usePhoneViewport(tester);
  final container = createTestContainer(session: session ?? UserSession.demo());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildFinoraTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('Plans', () {
    test('free limits and Premium', () {
      const free = Entitlements(premium: false);
      expect(free.maxInstitutions, 3);
      expect(free.canConnectMore(2), isTrue);
      expect(free.canConnectMore(3), isFalse);
      expect(free.canAddGoal(1), isTrue);
      expect(free.canAddGoal(2), isFalse);
      expect(free.historyMonths, 6);

      const premium = Entitlements(premium: true);
      expect(premium.maxInstitutions, isNull);
      expect(premium.canConnectMore(12), isTrue);
      expect(premium.historyMonths, 24);
    });

    test('yearly billing is cheaper than monthly', () {
      expect(PlusPricing.yearlyPerMonth, const Money.cents(492));
      expect(PlusPricing.yearlySavingPercent, 28);
      expect(PlusPricing.price(BillingPeriod.monthly), const Money.cents(690));
    });
  });

  group('Trial', () {
    test('runs 14 days, once, and shows in the calendar', () async {
      final container = createTestContainer();
      final session = container.read(sessionProvider.notifier);
      expect(container.read(isPlusProvider), isFalse);

      session.startTrial();
      final state = container.read(sessionProvider);
      expect(container.read(isPlusProvider), isTrue);
      expect(state.trialEndsAt, testNow.add(const Duration(days: 14)));
      expect(container.read(historyMonthsProvider), 24);
      final events = await container.read(calendarProvider.future);
      expect(
        events.map((event) => event.kind),
        contains(CalendarEventKind.trialEnd),
      );
      expect(
        events.map((event) => event.kind),
        isNot(contains(CalendarEventKind.plusRenewal)),
      );

      session.cancelPlus();
      session.startTrial();
      expect(container.read(isPlusProvider), isFalse);
    });

    test('an expired trial falls back to Free', () {
      final container = createTestContainer(
        session: UserSession.demo().copyWith(
          plan: FinoraPlan.plus,
          plusSince: testNow.subtract(const Duration(days: 20)),
          trialEndsAt: testNow.subtract(const Duration(days: 6)),
          trialUsed: true,
        ),
      );
      expect(container.read(sessionProvider).isPlus, isFalse);
      expect(container.read(entitlementsProvider).premium, isFalse);
      expect(container.read(sessionProvider).trialUsed, isTrue);
    });

    test('subscribing ends the trial and keeps the period', () {
      final container = createTestContainer();
      container.read(sessionProvider.notifier)
        ..startTrial()
        ..startPlus(period: BillingPeriod.monthly);
      final state = container.read(sessionProvider);
      expect(state.onTrial, isFalse);
      expect(state.billingPeriod, BillingPeriod.monthly);
      final restored = UserSession.decode(state.encode())!;
      expect(restored.billingPeriod, BillingPeriod.monthly);
      expect(restored.trialUsed, isTrue);
    });
  });

  testWidgets('a fourth bank on Free opens the paywall', (tester) async {
    final container = await _pump(tester, const ConnectionScreen());
    expect(find.text('Free plan: 3 of 3 banks'), findsOneWidget);

    await tester.tap(find.text('Connect').first);
    await tester.pumpAndSettle();
    expect(find.text('Connect more than 3 banks'), findsOneWidget);
    final connectedBefore = container
        .read(sessionProvider)
        .connectedInstitutionIds
        .length;

    await tester.tap(find.text('Try Premium free for 14 days'));
    await tester.pumpAndSettle();
    expect(container.read(isPlusProvider), isTrue);
    expect(find.text('Free plan: 3 of 3 banks'), findsNothing);

    await tester.tap(find.text('Connect').first);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      container.read(sessionProvider).connectedInstitutionIds.length,
      connectedBefore + 1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a third goal on Free opens the paywall', (tester) async {
    final demo = UserSession.demo();
    await _pump(
      tester,
      const GoalsScreen(),
      session: demo.copyWith(
        goals: [
          ...demo.goals,
          SavingsGoal(
            id: 'trip',
            name: 'Trip',
            target: const Money.cents(300000),
            deadline: DateTime(2027, 6),
          ),
        ],
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Add a goal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add a goal'));
    await tester.pumpAndSettle();
    expect(find.text('More than 2 goals'), findsOneWidget);
  });

  testWidgets('the plans screen compares Free and Premium', (tester) async {
    await _pump(tester, const PlusScreen());
    expect(find.text('Free'), findsWidgets);
    expect(find.textContaining('4.92'), findsOneWidget);

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.textContaining('6.90'), findsWidgets);
    expect(find.textContaining('4.92'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Coming to Premium'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Compare plans'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Finora Coach'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
