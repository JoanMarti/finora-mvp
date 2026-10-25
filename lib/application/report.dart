import 'package:finora/application/budgets.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Completed months a report exists for, most recent first.
final reportMonthsProvider = FutureProvider<List<DateTime>>((ref) async {
  final analysis = await ref.watch(spendingAnalysisProvider.future);
  return MonthlyReport.availableMonths(
    analysis.combined.cashFlowHistory,
    ref.watch(clockProvider)(),
  );
});

/// The report for one month (first day of the month).
final monthlyReportProvider = FutureProvider.family<MonthlyReport?, DateTime>((
  ref,
  month,
) async {
  final analysis = await ref.watch(spendingAnalysisProvider.future);
  final overview = await ref.watch(overviewProvider.future);
  final subscriptions = await ref.watch(subscriptionPlanProvider.future);
  return MonthlyReport.of(
    month: month,
    cashFlow: analysis.combined.cashFlowHistory,
    netWorth: overview.history,
    subscriptionsSaved: subscriptions.achievedSaving,
  );
});
