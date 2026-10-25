import 'dart:async';

import 'package:finora/app/theme.dart';
import 'package:finora/application/auth.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/data/demo_auth_service.dart';
import 'package:finora/domain/auth.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String authErrorMessage(AppLocalizations l10n, AuthError error) =>
    switch (error) {
      AuthError.emailTaken => l10n.authErrorEmailTaken,
      AuthError.invalidCredentials => l10n.authErrorInvalidCredentials,
      AuthError.invalidCode => l10n.authErrorInvalidCode,
      AuthError.weakPassword => l10n.authErrorWeakPassword,
      AuthError.invalidEmail => l10n.emailInvalid,
      AuthError.tooManyAttempts => l10n.authErrorTooManyAttempts,
      AuthError.unavailable => l10n.authErrorUnavailable,
    };

/// Short versions of the terms or the privacy notice.
Future<void> showLegalSheet(BuildContext context, {required bool privacy}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                privacy ? l10n.privacySheetTitle : l10n.termsSheetTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                privacy ? l10n.privacySheetBody : l10n.termsSheetBody,
                style: const TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.onChanged,
    this.initialValue = '',
    this.errorText,
    this.newPassword = true,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String initialValue;
  final String? errorText;

  /// Autofill hint: a new password at sign-up, the saved one at sign-in.
  final bool newPassword;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      initialValue: widget.initialValue,
      obscureText: !_visible,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      decoration: InputDecoration(
        labelText: l10n.passwordLabel,
        prefixIcon: const Icon(Icons.lock_outline),
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _visible ? l10n.hidePassword : l10n.showPassword,
          onPressed: () => setState(() => _visible = !_visible),
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// Strength bar and the rules a new password still needs.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({
    required this.password,
    required this.email,
    super.key,
  });

  final String password;
  final String email;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final missing = PasswordPolicy.missing(password, email: email);
    final strength = PasswordPolicy.strength(password, email: email);
    final (label, color, filled) = switch (strength) {
      PasswordStrength.weak => (l10n.passwordStrengthWeak, finoraDanger, 1),
      PasswordStrength.fair => (l10n.passwordStrengthFair, finoraWarning, 2),
      PasswordStrength.strong => (l10n.passwordStrengthStrong, finoraGreen, 3),
    };
    final rules = [
      (PasswordRule.length, l10n.passwordRuleLength(PasswordPolicy.minLength)),
      (PasswordRule.letter, l10n.passwordRuleLetter),
      (PasswordRule.digit, l10n.passwordRuleDigit),
      (PasswordRule.notEmail, l10n.passwordRuleNotEmail),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (password.isNotEmpty) ...[
          Row(
            children: [
              for (var index = 0; index < 3; index++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: index < filled ? color : finoraBorder,
                      borderRadius: BorderRadius.circular(finoraRadiusSmall),
                    ),
                  ),
                ),
                if (index < 2) const SizedBox(width: 4),
              ],
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final (rule, text) in rules)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    missing.contains(rule)
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle,
                    size: 14,
                    color: missing.contains(rule) ? finoraSlate : finoraGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      color: finoraMutedInk,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Sign-up form: name, e-mail, password, terms and the optional news.
class AccountStep extends ConsumerStatefulWidget {
  const AccountStep({required this.onCreated, super.key});

  /// Called once the account exists (or already existed for this e-mail in
  /// this session, when the user came back to this step).
  final VoidCallback onCreated;

  @override
  ConsumerState<AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends ConsumerState<AccountStep> {
  bool _submitted = false;
  bool _busy = false;
  AuthError? _error;

  Future<void> _create() async {
    setState(() => _submitted = true);
    final draft = ref.read(onboardingProvider);
    if (!draft.canRegister) return;
    final session = ref.read(sessionProvider);
    if (session.hasAccount && session.email == normalizeEmail(draft.email)) {
      widget.onCreated();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await ref
          .read(authServiceProvider)
          .register(draft.registration);
      ref
          .read(sessionProvider.notifier)
          .signedIn(
            account,
            acceptedTerms: true,
            marketingOptIn: draft.marketingOptIn,
          );
      ref.read(onboardingProvider.notifier).clearPassword();
      if (mounted) widget.onCreated();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);
    final error = _error;
    const linkStyle = TextStyle(
      color: finoraBlueText,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AutofillGroup(
            child: ListView(
              children: [
                Text(
                  l10n.createAccountTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.createAccountBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: draft.firstName,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: InputDecoration(
                    labelText: l10n.firstNameLabel,
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _submitted && !draft.hasFirstName
                        ? l10n.firstNameRequired
                        : null,
                  ),
                  onChanged: controller.setFirstName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: draft.email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: const Icon(Icons.mail_outline),
                    errorText:
                        (draft.email.isNotEmpty || _submitted) &&
                            !draft.hasValidEmail
                        ? l10n.emailInvalid
                        : null,
                  ),
                  onChanged: (value) {
                    controller.setEmail(value);
                    if (_error == AuthError.emailTaken) {
                      setState(() => _error = null);
                    }
                  },
                ),
                const SizedBox(height: 14),
                PasswordField(
                  initialValue: draft.password,
                  onChanged: controller.setPassword,
                  errorText: _submitted && !draft.hasValidPassword
                      ? l10n.authErrorWeakPassword
                      : null,
                ),
                const SizedBox(height: 10),
                PasswordChecklist(password: draft.password, email: draft.email),
                const SizedBox(height: 18),
                CheckboxListTile(
                  value: draft.acceptedTerms,
                  onChanged: (value) =>
                      controller.setAcceptedTerms(value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.acceptTermsPrefix),
                        TextSpan(
                          text: l10n.termsLink,
                          style: linkStyle,
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                showLegalSheet(context, privacy: false),
                        ),
                        TextSpan(text: l10n.acceptTermsMiddle),
                        TextSpan(
                          text: l10n.privacyLink,
                          style: linkStyle,
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                showLegalSheet(context, privacy: true),
                        ),
                        TextSpan(text: l10n.acceptTermsSuffix),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  subtitle: _submitted && !draft.acceptedTerms
                      ? Text(
                          l10n.termsRequired,
                          style: const TextStyle(color: finoraDanger),
                        )
                      : null,
                ),
                CheckboxListTile(
                  value: draft.marketingOptIn,
                  onChanged: (value) =>
                      controller.setMarketingOptIn(value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.marketingOptIn,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  _ErrorBanner(
                    message: authErrorMessage(l10n, error),
                    action: error == AuthError.emailTaken
                        ? TextButton(
                            onPressed: () => context.push('/sign-in'),
                            child: Text(l10n.signInInstead),
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.createAccountAction),
        ),
      ],
    );
  }
}

/// The 6-digit code sent to the new address.
class VerifyEmailStep extends ConsumerStatefulWidget {
  const VerifyEmailStep({
    required this.onVerified,
    required this.onChangeEmail,
    super.key,
  });

  final VoidCallback onVerified;
  final VoidCallback onChangeEmail;

  @override
  ConsumerState<VerifyEmailStep> createState() => _VerifyEmailStepState();
}

class _VerifyEmailStepState extends ConsumerState<VerifyEmailStep> {
  static const resendAfter = Duration(seconds: 30);

  String _code = '';
  bool _busy = false;
  AuthError? _error;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _email => ref.read(sessionProvider).email;

  Future<void> _verify() async {
    if (_code.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).verifyEmail(_email, _code);
      ref.read(sessionProvider.notifier).markEmailVerified();
      if (mounted) widget.onVerified();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(authServiceProvider).resendCode(_email);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.error);
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = null;
      _resendTimer = Timer(resendAfter, () {
        if (mounted) setState(() => _resendTimer = null);
      });
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.codeResent)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = ref.watch(sessionProvider.select((session) => session.email));
    final isDemo = ref.watch(authServiceProvider).isDemo;
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: finoraSoftBlue,
                  foregroundColor: finoraBlueText,
                  child: Icon(Icons.mark_email_unread_outlined, size: 28),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.verifyTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.verifyBody(email),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (isDemo) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: finoraMint,
                    borderRadius: BorderRadius.circular(finoraRadiusControl),
                  ),
                  child: Text(
                    l10n.verifyDemoHint(DemoAuthService.demoCode),
                    style: const TextStyle(
                      color: finoraGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  fontFeatures: finoraTabular,
                ),
                decoration: InputDecoration(
                  labelText: l10n.verifyCodeLabel,
                  errorText: error == null
                      ? null
                      : authErrorMessage(l10n, error),
                  errorMaxLines: 3,
                ),
                onChanged: (value) {
                  setState(() => _code = value);
                  if (value.length == 6) _verify();
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _resendTimer == null ? _resend : null,
                    child: Text(l10n.resendCode),
                  ),
                  TextButton(
                    onPressed: widget.onChangeEmail,
                    child: Text(l10n.changeEmail),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || _code.length != 6 ? null : _verify,
          child: Text(l10n.verifyAction),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
    decoration: BoxDecoration(
      color: finoraDanger.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(finoraRadiusControl),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: finoraDanger, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: finoraDanger, height: 1.35),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// Shared error banner for the auth screens.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.message, this.action, super.key});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      _ErrorBanner(message: message, action: action);
}
