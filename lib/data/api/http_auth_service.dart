import 'dart:convert';

import 'package:finora/data/api/api_client.dart';
import 'package:finora/domain/auth.dart';

/// Holds the access token for the current session. Kept in memory only; a
/// store build moves it to the platform keychain (`flutter_secure_storage`).
class AuthTokenHolder {
  String? token;
  Future<String?> read() async => token;
}

/// Accounts on the Finora backend (`/v1/auth/*` in docs/api.md).
class HttpAuthService implements AuthService {
  HttpAuthService(this._api, this._tokens);

  final FinoraApiClient _api;
  final AuthTokenHolder _tokens;

  @override
  bool get isDemo => false;

  Future<Object?> _call(String path, Map<String, Object?> body) async {
    try {
      return await _api.post(path, body);
    } on ApiException catch (error) {
      throw AuthException(_errorFor(error));
    }
  }

  static AuthError _errorFor(ApiException error) {
    String? code;
    try {
      final body = jsonDecode(error.message);
      if (body is Map) code = body['code'] as String?;
    } on FormatException {
      code = null;
    }
    final named = AuthError.values.where((value) => value.name == code);
    if (named.isNotEmpty) return named.first;
    return switch (error.statusCode) {
      401 => AuthError.invalidCredentials,
      409 => AuthError.emailTaken,
      429 => AuthError.tooManyAttempts,
      _ => AuthError.unavailable,
    };
  }

  AuthAccount _account(Object? body) {
    if (body is! Map || body['user'] is! Map) {
      throw const AuthException(AuthError.unavailable);
    }
    final user = (body['user'] as Map).cast<String, Object?>();
    final token = body['accessToken'] as String?;
    if (token != null) _tokens.token = token;
    return AuthAccount(
      id: '${user['id']}',
      email: '${user['email']}',
      firstName: '${user['firstName'] ?? ''}',
      emailVerified: user['emailVerified'] == true,
      accessToken: token,
    );
  }

  @override
  Future<AuthAccount> register(Registration registration) async => _account(
    await _call('/v1/auth/register', {
      'firstName': registration.firstName.trim(),
      'email': normalizeEmail(registration.email),
      'password': registration.password,
      'termsVersion': registration.acceptedTermsVersion,
      'marketing': registration.marketingOptIn,
    }),
  );

  @override
  Future<AuthAccount> verifyEmail(String email, String code) async => _account(
    await _call('/v1/auth/verify', {
      'email': normalizeEmail(email),
      'code': code.trim(),
    }),
  );

  @override
  Future<void> resendCode(String email) async {
    await _call('/v1/auth/resend', {'email': normalizeEmail(email)});
  }

  @override
  Future<AuthAccount> signIn(String email, String password) async => _account(
    await _call('/v1/auth/login', {
      'email': normalizeEmail(email),
      'password': password,
    }),
  );

  @override
  Future<void> requestPasswordReset(String email) async {
    await _call('/v1/auth/password-reset', {'email': normalizeEmail(email)});
  }
}
