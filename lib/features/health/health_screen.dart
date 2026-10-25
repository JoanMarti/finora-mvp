import 'package:finora/app/theme.dart';
import 'package:finora/application/health.dart';
import 'package:finora/domain/health.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

Color healthColor(HealthStatus status) => switch (status) {
  HealthStatus.good => finoraGreen,
  HealthStatus.fair => finoraWarning,
  HealthStatus.attention => finoraDanger,
  HealthStatus.missingData => finoraSlate,
};

IconData healthIcon(HealthFactorKind kind) => switch (kind) {
  HealthFactorKind.emergencyFund => Icons.shield_outlined,
  HealthFactorKind.savingsRate => Icons.savings_outlined,
  HealthFactorKind.pillar3a => Icons.account_balance_outlined,
  HealthFactorKind.housing => Icons.home_outlined,
  HealthFactorKind.retirement => Icons.beach_access_outlined,
  HealthFactorKind.fixedCosts => Icons.receipt_long_outlined,
};

/// Circular score from 0 to 100.
class HealthScoreRing extends StatelessWidget {
  const HealthScoreRing({
    required this.score,
    required this.status,
    this.size = 64,
    super.key,
  });
  final int score;
  final HealthStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: size / 9,
            backgroundColor: finoraSoftBlue,
            color: healthColor(status),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: size / 3,
                fontWeight: FontWeight.w800,
                color: finoraInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashboard entry: the score and the single most useful next step.
class HealthScoreCard extends ConsumerWidget {
  const HealthScoreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(financialHealthProvider).value;
    if (health == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final next = health.nextStep;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/health'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              HealthScoreRing(score: health.score, status: health.status),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.healthTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.healthStatus(health.status),
                      style: TextStyle(
                        color: healthColor(health.status),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      next == null
                          ? l10n.healthAllGood
                          : l10n.healthNextStep(
                              l10n.healthFactorTitle(next.kind),
                            ),
                      style: const TextStyle(
                        color: finoraMutedInk,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: finoraMutedInk),
            ],
          ),
        ),
      ),
    );
  }
}

/// The financial health check: score, every area with its evidence and a
/// way to act on it.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final health = ref.watch(financialHealthProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.healthTitle),
      ),
      body: FinoraPage(
        child: health.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.overviewUnavailable)),
          data: (data) => ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      HealthScoreRing(
                        score: data.score,
                        status: data.status,
                        size: 88,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.healthScoreOutOf(data.score),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.healthStatus(data.status),
                              style: TextStyle(
                                color: healthColor(data.status),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.healthIntro,
                              style: const TextStyle(
                                color: finoraMutedInk,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SectionTitle(l10n.healthAreasSection),
              for (final factor in data.factors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FactorCard(factor: factor),
                ),
              const SizedBox(height: 8),
              Text(
                l10n.healthDisclaimer,
                style: const TextStyle(
                  color: finoraMutedInk,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactorCard extends StatelessWidget {
  const _FactorCard({required this.factor});
  final HealthFactor factor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = healthColor(factor.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(healthIcon(factor.kind), color: finoraBlueText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.healthFactorTitle(factor.kind),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ValuePill(label: l10n.healthStatus(factor.status), color: color),
              ],
            ),
            if (factor.score != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: factor.score,
                  minHeight: 6,
                  backgroundColor: finoraSoftBlue,
                  color: color,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              l10n.healthFactorDetail(factor),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(factor.route),
                child: Text(l10n.healthFactorAction(factor)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
