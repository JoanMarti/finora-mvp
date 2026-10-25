import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/analysis.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
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
// Funnel tracking
// -----------------------------------------------------------------------------

enum OfferEventType { viewed, partnerClicked, dismissed }

/// One step in the offer funnel. It holds no personal or financial data:
/// only which kind of offer and what happened, which is what the business
/// needs to measure conversion and revenue per offer.
class OfferEvent {
  const OfferEvent({required this.kind, required this.type, required this.at});
  final OpportunityKind kind;
  final OfferEventType type;
  final DateTime at;
}

/// In-memory funnel log. A production build would forward these events to
/// a privacy-friendly analytics backend.
final offerTrackerProvider = NotifierProvider<OfferTracker, List<OfferEvent>>(
  OfferTracker.new,
);

class OfferTracker extends Notifier<List<OfferEvent>> {
  @override
  List<OfferEvent> build() => const [];

  void track(OpportunityKind kind, OfferEventType type) {
    state = [
      ...state,
      OfferEvent(kind: kind, type: type, at: ref.read(clockProvider)()),
    ];
  }

  int count(OfferEventType type) =>
      state.where((event) => event.type == type).length;
}
