import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/domain/health.dart';
import 'package:finora/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final manualAssetsProvider = Provider<List<ManualAsset>>(
  (ref) => ref.watch(sessionProvider.select((session) => session.manualAssets)),
);

/// The financial health check: six areas scored from the user's own data.
final financialHealthProvider = FutureProvider<FinancialHealth>((ref) async {
  final overview = await ref.watch(overviewProvider.future);
  final analysis = await ref.watch(spendingAnalysisProvider.future);
  final projection = await ref.watch(retirementProjectionProvider.future);
  final accounts = await ref.watch(accountsProvider.future);
  final assets = ref.watch(manualAssetsProvider);
  return FinancialHealth.of(
    HealthInput(
      overview: overview,
      targets: ref.watch(wealthTargetsProvider),
      monthlyIncome: analysis.combined.monthlyIncome,
      savingsRate: analysis.combined.savingsRate,
      fixedCostShare: analysis.fixedCostShare,
      mortgageDebt: Money.sum(
        accounts
            .where((account) => account.type == FinancialProductType.mortgage)
            .map((account) => account.balance.abs()),
      ),
      propertyValue: assets.totalOf(ManualAssetKind.property),
      retirementCoverage: projection.coverage,
      retirementIsExample: !ref.watch(hasOwnRetirementProfileProvider),
      hasPillar3a: accounts.any((account) => account.type.isRetirement),
    ),
  );
});
