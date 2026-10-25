import 'package:finora/app/theme.dart';
import 'package:finora/application/auth.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/auth.dart';
import 'package:finora/features/onboarding/account_steps.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sign-in for people who already have an account.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  String _email = '';
  String _password = '';
  bool _busy = false;
  AuthError? _error;

  bool get _canSubmit => isValidEmail(_email) && _password.isNotEmpty;

  Future<void> _signIn() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await ref
          .read(authServiceProvider)
          .signIn(_email, _password);
      ref.read(sessionProvider.notifier).signedIn(account);
      ref
          .read(onboardingProvider.notifier)
          .continueAfterSignIn(account.email, verified: account.emailVerified);
      if (mounted) context.go('/onboarding');
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ResetPasswordDialog(initialEmail: _email),
    );
    if (email == null) return;
    try {
      await ref.read(authServiceProvider).requestPasswordReset(email);
    } on AuthException {
      // Same answer either way: never reveal whether an address exists.
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.resetPasswordSent)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = _error;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: FinoraPage(
          maxWidth: 480,
          child: AutofillGroup(
            child: ListView(
              children: [
                Text(
                  l10n.signInTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.signInBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                  onChanged: (value) => setState(() => _email = value.trim()),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  newPassword: false,
                  onChanged: (value) => setState(() => _password = value),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: Text(l10n.forgotPassword),
                  ),
                ),
                if (error != null) ...[
                  AuthErrorBanner(message: authErrorMessage(l10n, error)),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy || !_canSubmit ? null : _signIn,
                  child: Text(l10n.signInAction),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    ref.read(onboardingProvider.notifier).setStep(1);
                    context.go('/onboarding');
                  },
                  child: Text(l10n.noAccountYet),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: finoraSlate),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.trustReadOnly,
                        style: const TextStyle(
                          color: finoraMutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late String _email = widget.initialEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.resetPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.resetPasswordBody),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.emailLabel),
            onChanged: (value) => setState(() => _email = value.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: isValidEmail(_email)
              ? () => Navigator.pop(context, _email)
              : null,
          child: Text(l10n.resetPasswordAction),
        ),
      ],
    );
  }
}
