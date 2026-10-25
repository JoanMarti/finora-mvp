import 'package:finora/app/layout.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Sign-up and sign-in frame. On desktop the form sits next to a brand
/// panel instead of floating alone in a wide window; on phones and
/// tablets it is just the form.
class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (FinoraWindow.of(context) != FinoraWindow.expanded) return child;
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: finoraInkGradient),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: finoraBlue,
                          borderRadius: BorderRadius.circular(
                            finoraRadiusControl,
                          ),
                        ),
                        child: const Text(
                          'F',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Finora',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.3,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    l10n.sidebarTagline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      l10n.welcomeBody,
                      style: const TextStyle(
                        color: finoraSilver,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  for (final (icon, text) in [
                    (Icons.visibility_outlined, l10n.trustReadOnly),
                    (Icons.lock_outline, l10n.trustControl),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(icon, color: finoraSilver, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
        Expanded(flex: 6, child: child),
      ],
    );
  }
}
