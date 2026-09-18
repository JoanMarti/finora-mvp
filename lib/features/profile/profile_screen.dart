import 'package:finora/app/theme.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              const Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: finoraInk,
                    foregroundColor: Colors.white,
                    child: Text(
                      'JM',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Joan',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'joan@example.com',
                          style: TextStyle(color: Color(0xFF66756F)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SectionTitle('Connections'),
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
                      trailing: Text('CHF'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: true,
                      onChanged: (_) {},
                      secondary: const Icon(Icons.notifications_none),
                      title: const Text('Data health alerts'),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('Privacy & security'),
                      trailing: Icon(Icons.chevron_right),
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
                onPressed: () => context.go('/onboarding'),
                child: const Text('Restart onboarding'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
