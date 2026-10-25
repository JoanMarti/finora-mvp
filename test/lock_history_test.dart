import 'dart:math';

import 'package:finora/app/app.dart';
import 'package:finora/app/bootstrap.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/application/app_lock.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/app_lock.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/overview/widgets/wealth_trajectory_card.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _lock = AppLock.create('1234', random: Random(1));
final _locked = UserSession.demo().copyWith(appLock: _lock, languageCode: 'en');

void main() {
  group('PIN', () {
    test('only a salted hash is kept', () {
      expect(_lock.verify('1234'), isTrue);
      expect(_lock.verify('4321'), isFalse);
      expect(_lock.pinHash, isNot(contains('1234')));
      final other = AppLock.create('1234');
      expect(other.salt, isNot(_lock.salt));
      expect(other.pinHash, isNot(_lock.pinHash));
      final restored = AppLock.fromJson(_lock.toJson())!;
      expect(restored.verify('1234'), isTrue);
      expect(restored.autoLockAfter, const Duration(minutes: 1));
    });

    test('accepts 4 to 6 digits', () {
      expect(AppLock.isValidPin('123'), isFalse);
      expect(AppLock.isValidPin('1234'), isTrue);
      expect(AppLock.isValidPin('123456'), isTrue);
      expect(AppLock.isValidPin('1234567'), isFalse);
      expect(AppLock.isValidPin('12a4'), isFalse);
    });
  });

  group('Lock controller', () {
    late DateTime now;
    ProviderContainer container(UserSession session) {
      now = testNow;
      final result = ProviderContainer(
        overrides: [
          ...demoOverrides(sessionStore: InMemorySessionStore(session)),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(result.dispose);
      return result;
    }

    test('starts locked and pauses after too many wrong PINs', () {
      final c = container(_locked);
      final lock = c.read(appLockProvider.notifier);
      expect(c.read(appLockProvider).locked, isTrue);

      for (var i = 1; i < AppLock.maxAttempts; i++) {
        expect(lock.unlock('0000'), UnlockResult.wrongPin);
      }
      expect(c.read(appLockProvider).failedAttempts, AppLock.maxAttempts - 1);
      expect(lock.unlock('0000'), UnlockResult.blocked);
      // Even the right PIN waits for the pause to end.
      expect(lock.unlock('1234'), UnlockResult.blocked);

      now = now.add(AppLock.cooldown);
      expect(lock.unlock('1234'), UnlockResult.unlocked);
      expect(c.read(appLockProvider).locked, isFalse);
    });

    test('locks again after the auto-lock time in the background', () {
      final c = container(_locked);
      final lock = c.read(appLockProvider.notifier)..unlock('1234');

      lock.appPaused();
      now = now.add(const Duration(seconds: 30));
      lock.appResumed();
      expect(c.read(appLockProvider).locked, isFalse);

      lock.appPaused();
      now = now.add(const Duration(minutes: 2));
      lock.appResumed();
      expect(c.read(appLockProvider).locked, isTrue);
    });

    test('turning the lock off unlocks; without a PIN nothing locks', () {
      final c = container(_locked);
      expect(c.read(appLockProvider).locked, isTrue);
      c.read(sessionProvider.notifier).setAppLock(null);
      expect(c.read(appLockProvider).locked, isFalse);
      c.read(appLockProvider.notifier).lockNow();
      expect(c.read(appLockProvider).locked, isFalse);
    });
  });

  group('History', () {
    test('six months free, 24 with Plus', () async {
      final free = createTestContainer();
      final plus = createTestContainer(
        session: UserSession.demo().copyWith(plan: FinoraPlan.plus),
      );
      expect((await free.read(overviewProvider.future)).history, hasLength(6));
      final long = await plus.read(overviewProvider.future);
      expect(long.history, hasLength(24));
      // The latest point is the same whatever the length.
      expect(
        long.history.last.balance,
        (await free.read(overviewProvider.future)).history.last.balance,
      );
    });
  });

  testWidgets('the PIN screen guards the app', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(session: _locked),
        child: const FinoraApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('TOTAL WEALTH'), findsNothing);

    for (final digit in ['9', '9', '9', '9']) {
      await tester.tap(find.text(digit));
    }
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.textContaining('Wrong PIN'), findsOneWidget);

    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.text(digit));
    }
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Enter your PIN'), findsNothing);
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plus members can look back 24 months', (tester) async {
    usePhoneViewport(tester);
    final container = createTestContainer(
      session: UserSession.demo().copyWith(plan: FinoraPlan.plus),
    );
    final overview = await tester.runAsync(
      () => container.read(overviewProvider.future),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFinoraTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: WealthTrajectoryCard(overview: overview!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('6 months'), findsOneWidget);
    await tester.tap(find.text('24 M'));
    await tester.pumpAndSettle();
    expect(find.text('24 months'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
