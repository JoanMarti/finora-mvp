import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
import 'package:finora/domain/app_lock.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/lock/lock_screen.dart';
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
              SectionTitle(l10n.planSection),
              Card(
                child: ListTile(
                  leading: Icon(
                    session.isPlus ? Icons.verified : Icons.auto_awesome,
                    color: session.isPlus ? finoraGreen : finoraBlueText,
                  ),
                  title: Text(
                    session.isPlus ? l10n.plusActive : l10n.planFree,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    session.isPlus ? l10n.plusManage : l10n.plusTeaser,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/plus'),
                ),
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
                      value: session.hideAmounts,
                      onChanged: ref
                          .read(sessionProvider.notifier)
                          .setHideAmounts,
                      secondary: const Icon(Icons.visibility_off_outlined),
                      title: Text(l10n.hideAmounts),
                      subtitle: Text(l10n.hideAmountsBody),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: session.appLock != null,
                      onChanged: (enabled) =>
                          _toggleAppLock(context, ref, enabled: enabled),
                      secondary: const Icon(Icons.pin_outlined),
                      title: Text(l10n.appLockSetting),
                      subtitle: Text(l10n.appLockSettingBody),
                    ),
                    if (session.appLock != null) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: Text(l10n.autoLockSetting),
                        trailing: DropdownButton<int>(
                          value: session.appLock!.autoLockAfter.inSeconds,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final seconds in const [0, 60, 300, 900])
                              DropdownMenuItem(
                                value: seconds,
                                child: Text(
                                  seconds == 0
                                      ? l10n.autoLockImmediately
                                      : l10n.autoLockAfterMinutes(seconds ~/ 60),
                                ),
                              ),
                          ],
                          onChanged: (seconds) {
                            if (seconds == null) return;
                            ref
                                .read(sessionProvider.notifier)
                                .setAppLock(
                                  session.appLock!.copyWith(
                                    autoLockAfter: Duration(seconds: seconds),
                                  ),
                                );
                          },
                        ),
                      ),
                    ],
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
                    SwitchListTile(
                      value: session.offersConsent ?? false,
                      onChanged: ref
                          .read(sessionProvider.notifier)
                          .setOffersConsent,
                      secondary: const Icon(Icons.savings_outlined),
                      title: Text(l10n.offersSetting),
                      subtitle: Text(l10n.offersSettingBody),
                    ),
                    if (session.dismissedOpportunities.isNotEmpty) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.visibility_outlined),
                        title: Text(
                          l10n.hiddenOffers(
                            session.dismissedOpportunities.length,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: ref
                              .read(sessionProvider.notifier)
                              .restoreOpportunities,
                          child: Text(l10n.showAgain),
                        ),
                      ),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(l10n.privacySecurity),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/privacy'),
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
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.query_stats),
                  title: Text(l10n.pilotMetricsTitle),
                  subtitle: Text(l10n.pilotMetricsTileBody),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/pilot-metrics'),
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

Future<void> _toggleAppLock(
  BuildContext context,
  WidgetRef ref, {
  required bool enabled,
}) async {
  final session = ref.read(sessionProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  if (enabled) {
    final pin = await showSetPinDialog(context);
    if (pin == null) return;
    session.setAppLock(AppLock.create(pin));
    messenger.showSnackBar(SnackBar(content: Text(l10n.appLockOn)));
    return;
  }
  final lock = ref.read(sessionProvider).appLock;
  if (lock == null) return;
  final pin = await showCurrentPinDialog(context);
  if (pin == null) return;
  if (!lock.verify(pin)) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.lockWrongPinShort)));
    return;
  }
  session.setAppLock(null);
  messenger.showSnackBar(SnackBar(content: Text(l10n.appLockOff)));
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
