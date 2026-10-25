import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/analysis.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/trust.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Analytics of every connected account, keyed by account.
final analyticsByAccountProvider =
    FutureProvider<Map<FinancialAccount, AccountAnalytics>>((ref) async {
      final accounts = await ref.watch(accountsProvider.future);
      final analytics = await Future.wait([
        for (final account in accounts)
          ref.watch(accountAnalyticsProvider(account.id).future),
      ]);
      return {
        for (var index = 0; index < accounts.length; index++)
          accounts[index]: analytics[index],
      };
    });

/// Income, spending, categories and bills across all everyday accounts.
final spendingAnalysisProvider = FutureProvider<SpendingAnalysis>((ref) async {
  final byAccount = await ref.watch(analyticsByAccountProvider.future);
  return SpendingAnalysis.combine(byAccount);
});

/// Savings opportunities the user agreed to see, best first. Empty until the
/// user gives express consent to have their data analysed for offers.
final opportunitiesProvider = FutureProvider<List<Opportunity>>((ref) async {
  final consent = ref.watch(
    sessionProvider.select((session) => session.offersConsent),
  );
  if (consent != true) return const [];
  final dismissed = ref.watch(
    sessionProvider.select((session) => session.dismissedOpportunities),
  );
  final now = ref.watch(clockProvider)();
  final byAccount = await ref.watch(analyticsByAccountProvider.future);
  final overview = await ref.watch(overviewProvider.future);
  final found = OpportunityEngine.detect(
    OpportunityInput(
      accounts: byAccount.keys.toList(),
      analytics: {
        for (final entry in byAccount.entries) entry.key.id: entry.value,
      },
      pillar3aContributionsThisYear: overview.pillar3aContributionsThisYear,
      now: now,
      propertyValue: ref
          .watch(sessionProvider.select((session) => session.manualAssets))
          .totalOf(ManualAssetKind.property),
    ),
  );
  return [
    for (final item in found)
      if (!dismissed.contains(item.id)) item,
  ];
});

/// Upper end of the yearly savings across all visible opportunities.
final potentialSavingProvider = Provider<Money>((ref) {
  final items = ref.watch(opportunitiesProvider).value ?? const [];
  return Money.sum(items.map((item) => item.savingHigh ?? Money.zero));
});

// -----------------------------------------------------------------------------
// Funnel and plan
// -----------------------------------------------------------------------------

/// Aggregated offer funnel kept on this device. A production build would
/// send the same counts (never personal data) to the analytics backend.
final funnelProvider = Provider<FunnelStats>(
  (ref) => ref.watch(sessionProvider.select((session) => session.funnel)),
);

/// Consent register, newest first.
final consentLogProvider = Provider<List<ConsentRecord>>(
  (ref) => ref
      .watch(sessionProvider.select((session) => session.consentLog))
      .reversed
      .toList(),
);

final isPlusProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider.select((session) => session.isPlus)),
);
