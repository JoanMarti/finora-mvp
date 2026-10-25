import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _SimulatedStatus { ready, connecting, connected, manual }

/// Simulates the bank hand-off. During onboarding it connects the
/// institutions the user selected; afterwards it adds new institutions.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  late final bool _addingToExisting;
  late final Map<String, _SimulatedStatus> _statuses;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _addingToExisting = session.onboardingCompleted;

    final Iterable<String> ids;
    if (_addingToExisting) {
      ids = InstitutionCatalogue.all
          .map((institution) => institution.id)
          .where((id) => !session.connectedInstitutionIds.contains(id));
    } else {
      final selected = ref.read(onboardingProvider).institutionIds;
      final wanted = selected.isEmpty
          ? InstitutionCatalogue.demoInstitutionIds
          : selected;
      // Keep catalogue order so the list is stable.
      ids = InstitutionCatalogue.all
          .map((institution) => institution.id)
          .where(wanted.contains);
    }

    _statuses = {
      for (final id in ids)
        id: !_addingToExisting && _isManual(id)
            ? _SimulatedStatus.manual
            : _SimulatedStatus.ready,
    };
  }

  bool _isManual(String id) => InstitutionCatalogue.byId(id)?.isManual ?? false;

  Future<void> _connect(String id) async {
    if (_addingToExisting) {
      final connected = ref.read(sessionProvider).connectedInstitutionIds;
      if (!ref.read(entitlementsProvider).canConnectMore(connected.length)) {
        await showPaywall(context, PaywallReason.banks);
        return;
      }
    }
    setState(() => _statuses[id] = _SimulatedStatus.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(
      () => _statuses[id] = _isManual(id)
          ? _SimulatedStatus.manual
          : _SimulatedStatus.connected,
    );
    if (_addingToExisting) {
      ref.read(sessionProvider.notifier).connect(id);
    }
  }

  Future<void> _connectAllAndContinue() async {
    if (_busy) return;
    setState(() => _busy = true);
    final pending = [
      for (final entry in _statuses.entries)
        if (entry.value == _SimulatedStatus.ready) entry.key,
    ];
    // Hand-offs run in parallel, as they would with real bank redirects.
    await Future.wait(pending.map(_connect));
    if (!mounted) return;
    final onboarding = ref.read(onboardingProvider);
    ref
        .read(sessionProvider.notifier)
        .completeOnboarding(
          email: onboarding.email,
          products: onboarding.products,
          connectedInstitutionIds: {
            for (final entry in _statuses.entries)
              if (entry.value == _SimulatedStatus.connected ||
                  entry.value == _SimulatedStatus.manual)
                entry.key,
          },
        );
    context.go('/home');
  }

  void _useDemoData() {
    ref
        .read(sessionProvider.notifier)
        .useDemoData(email: ref.read(onboardingProvider).email);
    context.go('/home');
  }

  void _leave() {
    if (_addingToExisting) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/accounts');
      }
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _statuses.values
        .where(
          (item) =>
              item == _SimulatedStatus.connected ||
              item == _SimulatedStatus.manual,
        )
        .length;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          _addingToExisting
              ? l10n.addInstitutionTitle
              : l10n.connectInstitutionsTitle,
        ),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: _leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FinoraPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _addingToExisting
                    ? l10n.bringAnotherInstitution
                    : l10n.bringAccountsTogether,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.connectionDemoNote,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_addingToExisting)
                _FreeLimitNote(
                  used: ref.watch(
                    sessionProvider.select(
                      (s) => s.connectedInstitutionIds.length,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              Expanded(
                child: _statuses.isEmpty
                    ? Center(
                        child: Text(
                          l10n.allInstitutionsConnected,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _statuses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final id = _statuses.keys.elementAt(index);
                          return _ConnectionTile(
                            institutionId: id,
                            status: _statuses[id]!,
                            onConnect: _busy ? null : () => _connect(id),
                          );
                        },
                      ),
              ),
              if (_addingToExisting)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton(
                    onPressed: _leave,
                    child: Text(l10n.commonDone),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: finoraSlate,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.readyCount(ready, _statuses.length),
                          style: const TextStyle(color: finoraMutedInk),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : _connectAllAndContinue,
                  child: Text(
                    ready == _statuses.length
                        ? l10n.viewMyOverview
                        : l10n.connectAndContinue,
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _useDemoData,
                    child: Text(l10n.useDemoDataInstead),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.institutionId,
    required this.status,
    required this.onConnect,
  });

  final String institutionId;
  final _SimulatedStatus status;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final institution = InstitutionCatalogue.byId(institutionId);
    final l10n = context.l10n;
    final isManual = institution?.isManual ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (institution != null)
              InstitutionBadge(institution: institution)
            else
              const SizedBox(width: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    InstitutionCatalogue.nameOf(institutionId),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    switch (status) {
                      _SimulatedStatus.ready =>
                        isManual
                            ? l10n.enterValueManually
                            : l10n.secureRedirectAvailable,
                      _SimulatedStatus.connecting => l10n.synchronisingAccounts,
                      _SimulatedStatus.connected => l10n.connectedConsentActive,
                      _SimulatedStatus.manual => l10n.manualValueReady,
                    },
                    style: const TextStyle(color: finoraMutedInk),
                  ),
                ],
              ),
            ),
            switch (status) {
              _SimulatedStatus.connecting => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              _SimulatedStatus.connected ||
              _SimulatedStatus.manual => Icon(
                Icons.check_circle,
                color: finoraGreen,
                semanticLabel: l10n.ready,
              ),
              _SimulatedStatus.ready => OutlinedButton(
                onPressed: onConnect,
                child: Text(
                  isManual ? l10n.add : l10n.connect,
                ),
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// "Free plan: 2 of 3 banks", with a way to see the plans.
class _FreeLimitNote extends ConsumerWidget {
  const _FreeLimitNote({required this.used});
  final int used;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(entitlementsProvider).maxInstitutions;
    if (limit == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        color: finoraSoftBlue,
        borderRadius: BorderRadius.circular(finoraRadiusControl),
        child: InkWell(
          borderRadius: BorderRadius.circular(finoraRadiusControl),
          onTap: () => context.push('/plus'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: finoraBlueText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.freeLimitNote(used.clamp(0, limit), limit),
                    style: const TextStyle(
                      color: finoraInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  l10n.paywallSeePlans,
                  style: const TextStyle(
                    color: finoraBlueText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(Icons.chevron_right, color: finoraBlueText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
