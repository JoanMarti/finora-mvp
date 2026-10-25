import 'dart:convert';
import 'dart:math';

import 'package:finora/domain/app_lock.dart';
import 'package:finora/domain/auth.dart';

/// Where the demo keeps its accounts.
abstract interface class AccountStore {
  String? load();
  Future<void> save(String value);
}

class InMemoryAccountStore implements AccountStore {
  String? _value;

  @override
  String? load() => _value;

  @override
  Future<void> save(String value) async => _value = value;
}

/// Accounts kept on this device for the demo. Passwords are stored only as
/// a salted, stretched hash. No e-mail is really sent: the code is always
/// [demoCode], which the sign-up screen shows.
class DemoAuthService implements AuthService {
  DemoAuthService(this._store, {Random? random})
    : _random = random ?? Random.secure();

  static const demoCode = '123456';
  static const maxAttempts = 5;

  final AccountStore _store;
  final Random _random;
  final Map<String, int> _failures = {};

  @override
  bool get isDemo => true;

  Map<String, Map<String, Object?>> _accounts() {
    try {
      final raw = jsonDecode(_store.load() ?? '{}');
      if (raw is! Map) return {};
      return {
        for (final entry in raw.entries)
          if (entry.value is Map)
            '${entry.key}': (entry.value as Map).cast<String, Object?>(),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> _save(Map<String, Map<String, Object?>> accounts) =>
      _store.save(jsonEncode(accounts));

  AuthAccount _toAccount(Map<String, Object?> record) => AuthAccount(
    id: '${record['id']}',
    email: '${record['email']}',
    firstName: '${record['firstName']}',
    emailVerified: record['verified'] == true,
  );

  void _guard(String key) {
    if ((_failures[key] ?? 0) >= maxAttempts) {
      throw const AuthException(AuthError.tooManyAttempts);
    }
  }

  Never _fail(String key, AuthError error) {
    _failures[key] = (_failures[key] ?? 0) + 1;
    throw AuthException(error);
  }

  @override
  Future<AuthAccount> register(Registration registration) async {
    final email = normalizeEmail(registration.email);
    if (!isValidEmail(email)) throw const AuthException(AuthError.invalidEmail);
    if (!PasswordPolicy.accepts(registration.password, email: email)) {
      throw const AuthException(AuthError.weakPassword);
    }
    final accounts = _accounts();
    if (accounts.containsKey(email)) {
      throw const AuthException(AuthError.emailTaken);
    }
    final salt = base64Url.encode([
      for (var i = 0; i < 16; i++) _random.nextInt(256),
    ]);
    final record = <String, Object?>{
      'id': 'usr_${base64Url.encode([for (var i = 0; i < 9; i++) _random.nextInt(256)])}',
      'email': email,
      'firstName': registration.firstName.trim(),
      'salt': salt,
      'hash': AppLock.hashPin(registration.password, salt),
      'verified': false,
      'termsVersion': registration.acceptedTermsVersion,
      'marketing': registration.marketingOptIn,
    };
    await _save({...accounts, email: record});
    return _toAccount(record);
  }

  @override
  Future<AuthAccount> verifyEmail(String email, String code) async {
    final key = 'code:${normalizeEmail(email)}';
    _guard(key);
    final accounts = _accounts();
    final record = accounts[normalizeEmail(email)];
    if (record == null) _fail(key, AuthError.invalidCode);
    if (code.trim() != demoCode) _fail(key, AuthError.invalidCode);
    _failures.remove(key);
    final verified = {...record, 'verified': true};
    await _save({...accounts, normalizeEmail(email): verified});
    return _toAccount(verified);
  }

  @override
  Future<void> resendCode(String email) async {
    // A new code would be e-mailed; the demo code never changes. Resending
    // also lifts a lockout, as a fresh code would.
    _failures.remove('code:${normalizeEmail(email)}');
  }

  @override
  Future<AuthAccount> signIn(String email, String password) async {
    final key = 'login:${normalizeEmail(email)}';
    _guard(key);
    final record = _accounts()[normalizeEmail(email)];
    if (record == null ||
        AppLock.hashPin(password, '${record['salt']}') != record['hash']) {
      _fail(key, AuthError.invalidCredentials);
    }
    _failures.remove(key);
    return _toAccount(record);
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> deleteAccount(String email) async {
    final accounts = _accounts()..remove(normalizeEmail(email));
    await _save(accounts);
  }
}
