import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/household.dart';
import 'package:finora/domain/planning.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final householdProvider = Provider<Household?>(
  (ref) => ref.watch(sessionProvider.select((session) => session.household)),
);

/// Combined net worth and the split of shared bills; `null` until the
/// partner is set up.
final householdSummaryProvider = FutureProvider<HouseholdSummary?>((ref) async {
  final household = ref.watch(householdProvider);
  if (household == null) return null;
  final overview = await ref.watch(overviewProvider.future);
  final analysis = await ref.watch(spendingAnalysisProvider.future);
  return HouseholdSummary.of(
    household,
    myNetWorth: overview.total,
    myMonthlyIncome: analysis.combined.monthlyIncome,
    sharedMonthlyBills: analysis.combined.recurringTotal,
  );
});

/// Retirement of both partners; `null` without the partner's pension
/// details.
final coupleRetirementProvider = FutureProvider<CoupleRetirement?>((ref) async {
  final household = ref.watch(householdProvider);
  final partner = household?.partnerRetirement;
  if (household == null || partner == null) return null;
  final me = await ref.watch(retirementProjectionProvider.future);
  return CoupleRetirement.of(
    me,
    RetirementProjection.of(
      partner,
      pillar3aBalance: household.partnerPillar3a,
      now: ref.watch(clockProvider)(),
    ),
    relationship: household.relationship,
  );
});

