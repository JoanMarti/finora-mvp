import 'package:finora/application/health.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dated events for the next twelve months, soonest first.
final calendarProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final now = ref.watch(clockProvider)();
  final byAccount = await ref.watch(analyticsByAccountProvider.future);
  final overview = await ref.watch(overviewProvider.future);
  final session = ref.watch(sessionProvider);
  return FinancialCalendar.of(
    CalendarInput(
      now: now,
      bills: [
        for (final analytics in byAccount.values) ...analytics.recurringPayments,
      ],
      goals: session.goals,
      assets: ref.watch(manualAssetsProvider),
      pillar3aPaid: overview.pillar3aContributionsThisYear,
      pillar3aLimit: ref.watch(wealthTargetsProvider).pillar3aAnnualLimit,
      hasPillar3a: byAccount.keys.any((account) => account.type.isRetirement),
      plusSince: session.isPlus ? session.plusSince : null,
    ),
  );
});
