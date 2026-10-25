import 'dart:async';

import 'package:finora/app/theme.dart';
import 'package:finora/application/app_lock.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/app_lock.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Covers the app with the PIN screen while it is locked. The app below
/// keeps its state but is neither painted nor reachable.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        controller.appPaused();
      case AppLifecycleState.resumed:
        controller.appResumed();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockProvider.select((state) => state.locked));
    return Stack(
      children: [
        Offstage(offstage: locked, child: widget.child),
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  UnlockResult? _result;
  bool _confirmReset = false;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _press(String digit) {
    if (_pin.length >= AppLock.maxLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _result = null;
    });
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    if (_pin.length < AppLock.minLength) return;
    final result = ref.read(appLockProvider.notifier).unlock(_pin);
    setState(() {
      _pin = '';
      _result = result;
    });
    if (result == UnlockResult.blocked) {
      // Refresh the countdown once a second while blocked.
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final until = ref.read(appLockProvider).blockedUntil;
        if (until == null || DateTime.now().isAfter(until)) timer.cancel();
        setState(() {});
      });
    }
  }

  void _reset() {
    ref.read(onboardingProvider.notifier).reset();
    ref.read(sessionProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(appLockProvider);
    final until = state.blockedUntil;
    final seconds = until == null
        ? 0
        : until.difference(DateTime.now()).inSeconds.clamp(0, 999);
    final message = switch (_result) {
      UnlockResult.wrongPin => l10n.lockWrongPin(
        AppLock.maxAttempts - state.failedAttempts,
      ),
      UnlockResult.blocked => l10n.lockBlocked(seconds),
      _ => '',
    };
    return Material(
      color: finoraCanvas,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _confirmReset
                  ? _ResetConfirmation(
                      onCancel: () => setState(() => _confirmReset = false),
                      onReset: _reset,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          color: finoraBlue,
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.lockTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Semantics(
                          label: l10n.lockDigitsEntered(_pin.length),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < AppLock.maxLength; i++)
                                Container(
                                  width: 14,
                                  height: 14,
                                  margin: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i < _pin.length
                                        ? finoraInk
                                        : finoraSoftBlue,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 36,
                          child: Center(
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: finoraDanger),
                            ),
                          ),
                        ),
                        _Keypad(
                          onDigit: _press,
                          onDelete: _delete,
                          onSubmit: _submit,
                          deleteLabel: l10n.lockDelete,
                          submitLabel: l10n.lockUnlock,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _confirmReset = true),
                          child: Text(l10n.lockForgot),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onDelete,
    required this.onSubmit,
    required this.deleteLabel,
    required this.submitLabel,
  });
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final String deleteLabel;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    Widget key({
      required Widget child,
      required VoidCallback onTap,
      required String label,
    }) => Padding(
      padding: const EdgeInsets.all(6),
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
    Widget digit(String value) => key(
      label: value,
      onTap: () => onDigit(value),
      child: ExcludeSemantics(
        child: Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
    );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final value in row) digit(value)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            key(
              label: deleteLabel,
              onTap: onDelete,
              child: const Icon(Icons.backspace_outlined),
            ),
            digit('0'),
            key(
              label: submitLabel,
              onTap: onSubmit,
              child: const Icon(Icons.check, color: finoraBlue),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResetConfirmation extends StatelessWidget {
  const _ResetConfirmation({required this.onCancel, required this.onReset});
  final VoidCallback onCancel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.lockResetTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(l10n.lockResetBody, style: const TextStyle(height: 1.4)),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: finoraDanger),
          onPressed: onReset,
          child: Text(l10n.lockResetAction),
        ),
        TextButton(onPressed: onCancel, child: Text(l10n.commonCancel)),
      ],
    );
  }
}

/// Asks for a new PIN twice. Returns the PIN, or `null` when cancelled.
Future<String?> showSetPinDialog(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _SetPinDialog());

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pin = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = context.l10n;
    if (!AppLock.isValidPin(_pin.text)) {
      setState(() => _error = l10n.lockPinInvalid);
    } else if (_pin.text != _repeat.text) {
      setState(() => _error = l10n.lockPinMismatch);
    } else {
      Navigator.pop(context, _pin.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      counterText: '',
    );
    return AlertDialog(
      title: Text(l10n.lockSetTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.lockSetBody, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          for (final (controller, label) in [
            (_pin, l10n.lockNewPin),
            (_repeat, l10n.lockRepeatPin),
          ])
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: AppLock.maxLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: decoration(label),
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: finoraDanger)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.lockSetAction)),
      ],
    );
  }
}

/// Asks for the current PIN, e.g. before turning the lock off. Returns
/// the PIN typed, or `null` when cancelled.
Future<String?> showCurrentPinDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.lockCurrentTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: AppLock.maxLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: dialogContext.l10n.lockCurrentPin,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(dialogContext.l10n.commonContinue),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
