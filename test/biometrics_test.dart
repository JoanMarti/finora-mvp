import 'dart:math';

import 'package:finora/app/app.dart';
import 'package:finora/app/bootstrap.dart';
import 'package:finora/application/app_lock.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/app_lock.dart';
import 'package:finora/domain/user_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class _FakeBiometrics implements BiometricAuth {
  _FakeBiometrics({required this.recognise});
  final bool recognise;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return recognise;
  }
}

final _lock = AppLock.create('1234', random: Random(1));

UserSession _session({required bool biometrics}) => UserSession.demo()
    .copyWith(
      languageCode: 'en',
      appLock: _lock.copyWith(biometrics: biometrics),
    );

List<Override> _overrides(UserSession session, BiometricAuth auth) => [
  ...demoOverrides(sessionStore: InMemorySessionStore(session)),
  clockProvider.overrideWithValue(() => testNow),
  biometricAuthProvider.overrideWithValue(auth),
];

void main() {
  test('the biometrics choice is saved with the lock', () {
    final restored = AppLock.fromJson(
      _lock.copyWith(biometrics: true).toJson(),
    )!;
    expect(restored.biometrics, isTrue);
    expect(restored.verify('1234'), isTrue);
    expect(AppLock.fromJson(_lock.toJson())!.biometrics, isFalse);
  });

  test('a recognised finger unlocks; biometrics off never prompts', () async {
    final yes = _FakeBiometrics(recognise: true);
    final container = ProviderContainer(
      overrides: _overrides(_session(biometrics: true), yes),
    );
    addTearDown(container.dispose);
    expect(container.read(appLockProvider).locked, isTrue);
    expect(
      await container.read(appLockProvider.notifier).unlockWithBiometrics('x'),
      isTrue,
    );
    expect(container.read(appLockProvider).locked, isFalse);

    final off = _FakeBiometrics(recognise: true);
    final second = ProviderContainer(
      overrides: _overrides(_session(biometrics: false), off),
    );
    addTearDown(second.dispose);
    expect(
      await second.read(appLockProvider.notifier).unlockWithBiometrics('x'),
      isFalse,
    );
    expect(off.prompts, 0);
    expect(second.read(appLockProvider).locked, isTrue);
  });

  testWidgets('the lock screen asks for the finger on start', (tester) async {
    usePhoneViewport(tester);
    final auth = _FakeBiometrics(recognise: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(_session(biometrics: true), auth),
        child: const FinoraApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(auth.prompts, 1);
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
  });

  testWidgets('when not recognised the PIN keypad stays', (tester) async {
    usePhoneViewport(tester);
    final auth = _FakeBiometrics(recognise: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(_session(biometrics: true), auth),
        child: const FinoraApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not recognised. Enter your PIN.'), findsOneWidget);
    expect(find.text('Use fingerprint or face'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
