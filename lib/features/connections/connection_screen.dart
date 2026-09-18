import 'package:finora/app/theme.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _SimulatedStatus { ready, connecting, connected, manual }

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  late Map<String, _SimulatedStatus> statuses;

  @override
  void initState() {
    super.initState();
    final selected = ref.read(onboardingProvider).institutionIds;
    final ids = selected.isEmpty
        ? const {'ubs', 'zkb', 'swissquote', 'frankly'}
        : selected;
    statuses = {
      for (final id in ids)
        id: const {'frankly', 'viac', 'finpension'}.contains(id)
            ? _SimulatedStatus.manual
            : _SimulatedStatus.ready,
    };
  }

  Future<void> _connect(String id) async {
    setState(() => statuses[id] = _SimulatedStatus.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (mounted) setState(() => statuses[id] = _SimulatedStatus.connected);
  }

  Future<void> _connectAll() async {
    for (final id in statuses.keys.toList()) {
      if (statuses[id] == _SimulatedStatus.ready) await _connect(id);
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final connected = statuses.values
        .where(
          (item) =>
              item == _SimulatedStatus.connected ||
              item == _SimulatedStatus.manual,
        )
        .length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Connect institutions'),
        leading: IconButton(
          onPressed: () => context.go('/onboarding'),
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
                'Bring your accounts together',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'This demo simulates the bank hand-off, consent and first synchronisation.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView.separated(
                  itemCount: statuses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final id = statuses.keys.elementAt(index);
                    final status = statuses[id]!;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: finoraMint,
                              child: Text(
                                id
                                    .substring(0, id.length.clamp(0, 2))
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: finoraGreen,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _name(id),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _statusLabel(status),
                                    style: const TextStyle(
                                      color: Color(0xFF66756F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (status == _SimulatedStatus.connecting)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            else if (status == _SimulatedStatus.connected ||
                                status == _SimulatedStatus.manual)
                              const Icon(Icons.check_circle, color: finoraGreen)
                            else
                              OutlinedButton(
                                onPressed: () => _connect(id),
                                child: const Text('Connect'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Color(0xFF6B7974),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$connected of ${statuses.length} ready · read-only access',
                        style: const TextStyle(color: Color(0xFF6B7974)),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _connectAll,
                child: Text(
                  connected == statuses.length
                      ? 'View my overview'
                      : 'Connect and continue',
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Use demo data instead'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _name(String id) =>
    const {
      'ubs': 'UBS',
      'zkb': 'Zürcher Kantonalbank',
      'postfinance': 'PostFinance',
      'raiffeisen': 'Raiffeisen',
      'swissquote': 'Swissquote',
      'julius-baer': 'Julius Baer',
      'pictet': 'Pictet',
      'frankly': 'frankly',
      'viac': 'VIAC',
      'finpension': 'finpension',
    }[id] ??
    id;

String _statusLabel(_SimulatedStatus status) => switch (status) {
  _SimulatedStatus.ready => 'Secure bank redirect available',
  _SimulatedStatus.connecting => 'Synchronising accounts…',
  _SimulatedStatus.connected => 'Connected · consent active',
  _SimulatedStatus.manual => 'Manual value ready',
};
