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

/// The offer to show next to a bill, if there is one.
Opportunity? hintForBill(List<Opportunity> items, RecurringPayment bill) {
  Opportunity? find(OpportunityKind kind, {bool sameMerchant = true}) => items
      .where(
        (item) =>
            item.kind == kind && (!sameMerchant || item.subject == bill.merchant),
      )
      .firstOrNull;
  return switch (bill.category) {
    BillCategory.healthInsurance => find(OpportunityKind.healthInsuranceSwitch),
    BillCategory.householdInsurance => find(OpportunityKind.householdInsurance),
    BillCategory.phoneInternet => find(OpportunityKind.telecomPlan),
    BillCategory.streaming || BillCategory.membership => find(
      OpportunityKind.subscriptionsReview,
      sameMerchant: false,
    ),
    BillCategory.electricity || BillCategory.radioTvFee => null,
  };
}

/// Offers about one account (savings rate, 3a fees, card, mortgage).
final accountOpportunitiesProvider =
    Provider.family<List<Opportunity>, String>(
      (ref, accountId) => [
        for (final item in ref.watch(opportunitiesProvider).value ?? const [])
          if (item.accountId == accountId) item,
      ],
    );

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

/// Whether Premium is unlocked right now (a running trial counts).
final isPlusProvider = Provider<bool>((ref) {
  final now = ref.watch(clockProvider)();
  return ref.watch(sessionProvider.select((s) => s.isPremiumAt(now)));
});

/// Limits and features of the current plan.
final entitlementsProvider = Provider<Entitlements>(
  (ref) => Entitlements(premium: ref.watch(isPlusProvider)),
);
