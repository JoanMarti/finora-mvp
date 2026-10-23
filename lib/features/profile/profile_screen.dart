import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final institutions =
        ref.watch(institutionsProvider).value ?? const <Institution>[];
    final connections =
        ref.watch(connectionsProvider).value ?? const <InstitutionConnection>[];
    final l10n = context.l10n;
    final languageCode = session.languageCode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.navProfile),
      ),
      body: SafeArea(
        top: false,
        child: FinoraPage(
          child: ListView(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: finoraInk,
                    foregroundColor: Colors.white,
                    child: Text(
                      session.initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.displayName ?? l10n.you,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          session.email.isEmpty
                              ? l10n.demoProfile
                              : session.email,
                          style: const TextStyle(color: finoraMutedInk),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SectionTitle(l10n.connectionsSection),
              if (connections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    l10n.noInstitutionsConnected,
                    style: const TextStyle(color: finoraMutedInk),
                  ),
                ),
              for (final connection in connections)
                Builder(
                  builder: (context) {
                    final institution = institutions
                        .where((item) => item.id == connection.institutionId)
                        .firstOrNull;
                    if (institution == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: InstitutionBadge(institution: institution),
                          title: Text(
                            institution.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: StatusPill(status: connection.status),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/institution/${institution.id}'),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/connect'),
                icon: const Icon(Icons.add),
                label: Text(l10n.addConnection),
              ),
              SectionTitle(l10n.preferencesSection),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.translate),
                      title: Text(l10n.language),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            languageCode == null
                                ? l10n.languageSystem
                                : finoraLanguages[languageCode] ?? languageCode,
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => _chooseLanguage(context, ref, languageCode),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.currency_franc),
                      title: Text(l10n.displayCurrency),
                      subtitle: Text(l10n.moreCurrenciesSoon),
                      trailing: const Text('CHF'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: session.dataHealthAlerts,
                      onChanged: ref
                          .read(sessionProvider.notifier)
                          .setDataHealthAlerts,
                      secondary: const Icon(Icons.notifications_none),
                      title: Text(l10n.dataHealthAlerts),
                      subtitle: Text(l10n.dataHealthAlertsBody),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(l10n.privacySecurity),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPrivacySheet(context),
                    ),
                  ],
                ),
              ),
              SectionTitle(l10n.aboutDemoSection),
              Card(
                color: finoraMint,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    l10n.aboutDemoBody,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => _confirmRestart(context, ref),
                child: Text(l10n.restartOnboarding),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPrivacySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.privacySecurity,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _PrivacyLine(
              icon: Icons.visibility_outlined,
              text: context.l10n.privacyReadOnly,
            ),
            _PrivacyLine(
              icon: Icons.phone_iphone,
              text: context.l10n.privacyDeviceOnly,
            ),
            _PrivacyLine(
              icon: Icons.key_off_outlined,
              text: context.l10n.privacyNoCredentials,
            ),
          ],
        ),
      ),
    ),
  );
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: finoraBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}

Future<void> _confirmRestart(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.restartOnboardingTitle),
      content: Text(dialogContext.l10n.restartOnboardingBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(dialogContext.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(dialogContext.l10n.restart),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  ref.read(onboardingProvider.notifier).reset();
  ref.read(sessionProvider.notifier).reset();
  // The router redirects to onboarding once the session is cleared.
}

/// Lets the user pick the app language or follow the device.
Future<void> _chooseLanguage(
  BuildContext context,
  WidgetRef ref,
  String? current,
) async {
  const system = '';
  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      Widget option(String value, String label) => ListTile(
        title: Text(label),
        trailing: (current ?? system) == value
            ? const Icon(Icons.check, color: finoraBlueText)
            : null,
        onTap: () => Navigator.pop(dialogContext, value),
      );
      return SimpleDialog(
        title: Text(l10n.language),
        children: [
          option(system, l10n.languageSystem),
          for (final entry in finoraLanguages.entries)
            option(entry.key, entry.value),
        ],
      );
    },
  );
  if (choice == null) return;
  ref
      .read(sessionProvider.notifier)
      .setLanguage(choice == system ? null : choice);
}
