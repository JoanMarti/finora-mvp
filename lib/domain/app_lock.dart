import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Device-only PIN lock. Only a salted, stretched hash of the PIN is kept;
/// the PIN itself is never stored.
class AppLock {
  const AppLock({
    required this.salt,
    required this.pinHash,
    this.autoLockAfter = const Duration(minutes: 1),
    this.biometrics = false,
  });

  /// Creates the lock for a new [pin] with a fresh random salt.
  factory AppLock.create(String pin, {Duration? autoLockAfter, Random? random}) {
    final generator = random ?? Random.secure();
    final salt = base64Url.encode([
      for (var i = 0; i < 16; i++) generator.nextInt(256),
    ]);
    return AppLock(
      salt: salt,
      pinHash: hashPin(pin, salt),
      autoLockAfter: autoLockAfter ?? const Duration(minutes: 1),
    );
  }

  static const minLength = 4;
  static const maxLength = 6;

  /// Wrong attempts before a pause, and how long the pause lasts.
  static const maxAttempts = 5;
  static const cooldown = Duration(seconds: 30);

  static const _rounds = 10000;

  final String salt;
  final String pinHash;

  /// Time in the background after which the app locks again.
  final Duration autoLockAfter;

  /// Fingerprint or face can unlock; the PIN always works as a fallback.
  final bool biometrics;

  static bool isValidPin(String pin) =>
      RegExp(r'^\d+$').hasMatch(pin) &&
      pin.length >= minLength &&
      pin.length <= maxLength;

  /// SHA-256 stretched over [_rounds] rounds: slow enough to make guessing a
  /// copied value expensive, fast enough for a phone.
  static String hashPin(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$pin')).bytes;
    for (var round = 1; round < _rounds; round++) {
      digest = sha256.convert([...digest, ...utf8.encode(salt)]).bytes;
    }
    return base64Url.encode(digest);
  }

  bool verify(String pin) => hashPin(pin, salt) == pinHash;

  AppLock copyWith({Duration? autoLockAfter, bool? biometrics}) => AppLock(
    salt: salt,
    pinHash: pinHash,
    autoLockAfter: autoLockAfter ?? this.autoLockAfter,
    biometrics: biometrics ?? this.biometrics,
  );

  Map<String, Object?> toJson() => {
    'salt': salt,
    'pinHash': pinHash,
    'autoLockSeconds': autoLockAfter.inSeconds,
    'biometrics': biometrics,
  };

  static AppLock? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final salt = raw['salt'];
    final hash = raw['pinHash'];
    if (salt is! String || hash is! String) return null;
    final seconds = raw['autoLockSeconds'];
    return AppLock(
      salt: salt,
      pinHash: hash,
      autoLockAfter: Duration(seconds: seconds is int ? seconds : 60),
      biometrics: raw['biometrics'] == true,
    );
  }
}

/// The device's fingerprint or face check.
abstract interface class BiometricAuth {
  /// Whether the device can check a fingerprint or face right now (hardware
  /// present and at least one enrolled).
  Future<bool> isAvailable();

  /// Shows the system prompt; `true` when the user was recognised.
  Future<bool> authenticate(String reason);
}

/// No biometrics (web, tests): the PIN is the only way in.
class NoBiometrics implements BiometricAuth {
  const NoBiometrics();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
