import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
import 'package:finora/domain/models.dart';
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Profile'),
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
                          session.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          session.email.isEmpty ? 'Demo profile' : session.email,
                          style: const TextStyle(color: finoraMutedInk),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SectionTitle('Connections'),
              if (connections.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'No institutions connected yet.',
                    style: TextStyle(color: finoraMutedInk),
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
                label: const Text('Add connection'),
              ),
              const SectionTitle('Preferences'),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.currency_franc),
                      title: Text('Display currency'),
                      subtitle: Text('More currencies are coming soon'),
                      trailing: Text('CHF'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: session.dataHealthAlerts,
                      onChanged: ref
                          .read(sessionProvider.notifier)
                          .setDataHealthAlerts,
                      secondary: const Icon(Icons.notifications_none),
                      title: const Text('Data health alerts'),
                      subtitle: const Text(
                        'Tell me when a connection is stale or needs consent',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Privacy & security'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPrivacySheet(context),
                    ),
                  ],
                ),
              ),
              const SectionTitle('About this demo'),
              const Card(
                color: finoraMint,
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'All balances and transactions are fictional. No credentials, consent tokens or personal financial data are stored.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => _confirmRestart(context, ref),
                child: const Text('Restart onboarding'),
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
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy & security',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 16),
            _PrivacyLine(
              icon: Icons.visibility_outlined,
              text: 'Read-only: Finora can never pay, transfer or trade.',
            ),
            _PrivacyLine(
              icon: Icons.phone_iphone,
              text:
                  'This demo stores only your onboarding choices on this device.',
            ),
            _PrivacyLine(
              icon: Icons.key_off_outlined,
              text: 'No bank credentials or consent tokens are collected.',
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
      title: const Text('Restart onboarding?'),
      content: const Text(
        'Your demo profile and connections on this device will be cleared.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Restart'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  ref.read(onboardingProvider.notifier).reset();
  ref.read(sessionProvider.notifier).reset();
  // The router redirects to onboarding once the session is cleared.
}
