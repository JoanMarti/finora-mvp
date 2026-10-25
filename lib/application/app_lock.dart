import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/app_lock.dart';
import 'package:finora/data/local_biometrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LockState {
  const LockState({
    required this.locked,
    this.failedAttempts = 0,
    this.blockedUntil,
  });

  final bool locked;
  final int failedAttempts;

  /// After too many wrong PINs, no attempt is accepted before this time.
  final DateTime? blockedUntil;
}

enum UnlockResult { unlocked, wrongPin, blocked }

/// Fingerprint or face check; none on the web.
final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => kIsWeb ? const NoBiometrics() : LocalBiometrics(),
);

/// Whether this device offers fingerprint or face unlock.
final biometricsAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricAuthProvider).isAvailable(),
);

final appLockProvider = NotifierProvider<AppLockController, LockState>(
  AppLockController.new,
);

class AppLockController extends Notifier<LockState> {
  DateTime? _backgroundedAt;

  AppLock? get _lock => ref.read(sessionProvider).appLock;
  DateTime get _now => ref.read(clockProvider)();

  @override
  LockState build() {
    // Turning the lock off unlocks immediately; turning it on does not
    // lock the user out of the screen they are on.
    ref.listen(
      sessionProvider.select((session) => session.appLock != null),
      (_, enabled) {
        if (!enabled) state = const LockState(locked: false);
      },
    );
    // A cold start with a PIN set begins locked.
    return LockState(locked: ref.read(sessionProvider).appLock != null);
  }

  /// Unlocks after a successful fingerprint or face check, when the user
  /// turned it on and is not blocked after wrong PINs.
  Future<bool> unlockWithBiometrics(String reason) async {
    final lock = _lock;
    if (lock == null || !lock.biometrics || !state.locked) return false;
    final blockedUntil = state.blockedUntil;
    if (blockedUntil != null && _now.isBefore(blockedUntil)) return false;
    final recognised = await ref
        .read(biometricAuthProvider)
        .authenticate(reason);
    if (recognised) state = const LockState(locked: false);
    return recognised;
  }

  UnlockResult unlock(String pin) {
    final lock = _lock;
    if (lock == null) {
      state = const LockState(locked: false);
      return UnlockResult.unlocked;
    }
    final now = _now;
    final blockedUntil = state.blockedUntil;
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      return UnlockResult.blocked;
    }
    if (lock.verify(pin)) {
      state = const LockState(locked: false);
      return UnlockResult.unlocked;
    }
    final attempts = state.failedAttempts + 1;
    if (attempts >= AppLock.maxAttempts) {
      state = LockState(locked: true, blockedUntil: now.add(AppLock.cooldown));
      return UnlockResult.blocked;
    }
    state = LockState(locked: true, failedAttempts: attempts);
    return UnlockResult.wrongPin;
  }

  void lockNow() {
    if (_lock != null) state = const LockState(locked: true);
  }

  void appPaused() => _backgroundedAt = _now;

  /// Locks again when the app was in the background for longer than the
  /// chosen auto-lock time.
  void appResumed() {
    final lock = _lock;
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (lock == null || since == null) return;
    if (_now.difference(since) >= lock.autoLockAfter) lockNow();
  }
}
