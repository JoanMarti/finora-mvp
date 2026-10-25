import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/budgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// This month's budgets against spending in the everyday accounts.
final budgetSummaryProvider = FutureProvider<BudgetSummary>((ref) async {
  final analysis = await ref.watch(spendingAnalysisProvider.future);
  return BudgetSummary.of(
    ref.watch(sessionProvider.select((session) => session.budgets)),
    analysis.combined.spendingCategories,
    ref.watch(clockProvider)(),
  );
});

/// Optional subscriptions with the user's keep/cancel decisions.
final subscriptionPlanProvider = FutureProvider<SubscriptionPlan>((ref) async {
  final analysis = await ref.watch(spendingAnalysisProvider.future);
  return SubscriptionPlan.of(
    analysis.combined.recurringPayments,
    ref.watch(
      sessionProvider.select((session) => session.subscriptionDecisions),
    ),
  );
});
