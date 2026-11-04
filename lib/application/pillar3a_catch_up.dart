import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/pillar3a_catch_up.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the connected accounts show as paid into Pillar 3a in each past
/// year that can still be caught up.
final pillar3aPaidByYearProvider = FutureProvider<Map<int, Money>>((ref) async {
  final repository = ref.watch(financialRepositoryProvider);
  final year = ref.watch(clockProvider)().year;
  final first = year - Pillar3aCatchUpRules.yearsBack >
          Pillar3aCatchUpRules.firstGapYear
      ? year - Pillar3aCatchUpRules.yearsBack
      : Pillar3aCatchUpRules.firstGapYear;
  return {
    for (var gapYear = first; gapYear < year; gapYear++)
      gapYear: await repository.getPillar3aContributions(year: gapYear),
  };
});
