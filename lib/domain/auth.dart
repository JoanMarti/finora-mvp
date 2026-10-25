/// Accounts: registration, e-mail verification and sign-in.
///
/// The domain only describes the rules and the boundary; the demo keeps
/// accounts on the device and a backend build talks to `/v1/auth/*`.
library;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

/// Normalised form used to compare and store e-mail addresses.
String normalizeEmail(String email) => email.trim().toLowerCase();

/// Something a password still needs.
enum PasswordRule { length, letter, digit, notEmail }

enum PasswordStrength { weak, fair, strong }

/// Rules for new passwords. Kept simple and explained in the form, in line
/// with current guidance: length matters more than symbol rules.
abstract final class PasswordPolicy {
  static const minLength = 10;

  /// The rules [password] does not meet yet; empty means it is accepted.
  static List<PasswordRule> missing(String password, {String email = ''}) {
    final local = normalizeEmail(email).split('@').first;
    return [
      if (password.length < minLength) PasswordRule.length,
      if (!RegExp('[A-Za-zÀ-ÿ]').hasMatch(password)) PasswordRule.letter,
      if (!RegExp(r'\d').hasMatch(password)) PasswordRule.digit,
      if (local.length >= 3 && password.toLowerCase().contains(local))
        PasswordRule.notEmail,
    ];
  }

  static bool accepts(String password, {String email = ''}) =>
      missing(password, email: email).isEmpty;

  static PasswordStrength strength(String password, {String email = ''}) {
    if (!accepts(password, email: email)) return PasswordStrength.weak;
    final classes = [
      RegExp('[a-z]'),
      RegExp('[A-Z]'),
      RegExp(r'\d'),
      RegExp(r'[^A-Za-z\d]'),
    ].where((pattern) => pattern.hasMatch(password)).length;
    return password.length >= 14 || classes >= 4
        ? PasswordStrength.strong
        : PasswordStrength.fair;
  }
}

/// Current version of the terms of use and privacy notice. Bump it when
/// the texts change so existing users are asked again.
const termsVersion = '2026-10';

/// An account as the auth service reports it.
class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.email,
    required this.firstName,
    required this.emailVerified,
    this.accessToken,
  });

  final String id;
  final String email;
  final String firstName;
  final bool emailVerified;

  /// Bearer token for the backend; `null` in the demo.
  final String? accessToken;

  AuthAccount copyWith({bool? emailVerified, String? accessToken}) =>
      AuthAccount(
        id: id,
        email: email,
        firstName: firstName,
        emailVerified: emailVerified ?? this.emailVerified,
        accessToken: accessToken ?? this.accessToken,
      );
}

enum AuthError {
  emailTaken,
  invalidCredentials,
  invalidCode,
  weakPassword,
  invalidEmail,
  tooManyAttempts,
  unavailable,
}

class AuthException implements Exception {
  const AuthException(this.error);
  final AuthError error;

  @override
  String toString() => 'AuthException(${error.name})';
}

/// What a sign-up form sends.
class Registration {
  const Registration({
    required this.firstName,
    required this.email,
    required this.password,
    required this.acceptedTermsVersion,
    this.marketingOptIn = false,
  });

  final String firstName;
  final String email;
  final String password;
  final String acceptedTermsVersion;
  final bool marketingOptIn;
}

/// Account boundary. Every method throws [AuthException] on failure.
abstract interface class AuthService {
  /// Creates the account and sends a 6-digit code to the e-mail address.
  Future<AuthAccount> register(Registration registration);

  /// Confirms the e-mail address with the code that was sent.
  Future<AuthAccount> verifyEmail(String email, String code);

  /// Sends a new verification code.
  Future<void> resendCode(String email);

  Future<AuthAccount> signIn(String email, String password);

  /// Sends a reset link. Always succeeds, so it never reveals whether an
  /// address has an account.
  Future<void> requestPasswordReset(String email);

  /// Deletes the account and everything stored with it on the server.
  /// Required by Google Play for apps with sign-up.
  Future<void> deleteAccount(String email);

  /// Whether this build uses a demo account store rather than a server.
  bool get isDemo;
}
