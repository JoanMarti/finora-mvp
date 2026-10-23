import 'package:finora/app/theme.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          _addingToExisting ? 'Add an institution' : 'Connect institutions',
        ),
        leading: IconButton(
          tooltip: 'Back',
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
                    ? 'Bring in another institution'
                    : 'Bring your accounts together',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'This demo simulates the bank hand-off, consent and first synchronisation.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              Expanded(
                child: _statuses.isEmpty
                    ? const Center(
                        child: Text(
                          'Every supported institution is already connected.',
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
                    child: const Text('Done'),
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
                          '$ready of ${_statuses.length} ready · read-only access',
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
                        ? 'View my overview'
                        : 'Connect and continue',
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _useDemoData,
                    child: const Text('Use demo data instead'),
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
                    _statusLabel(status, institution?.isManual ?? false),
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
              _SimulatedStatus.manual => const Icon(
                Icons.check_circle,
                color: finoraGreen,
                semanticLabel: 'Ready',
              ),
              _SimulatedStatus.ready => OutlinedButton(
                onPressed: onConnect,
                child: Text(
                  (institution?.isManual ?? false) ? 'Add' : 'Connect',
                ),
              ),
            },
          ],
        ),
      ),
    );
  }
}

String _statusLabel(_SimulatedStatus status, bool isManual) =>
    switch (status) {
      _SimulatedStatus.ready =>
        isManual ? 'Enter the value manually' : 'Secure bank redirect available',
      _SimulatedStatus.connecting => 'Synchronising accounts…',
      _SimulatedStatus.connected => 'Connected · consent active',
      _SimulatedStatus.manual => 'Manual value ready',
    };
