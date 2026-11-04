import 'package:finora/domain/models.dart';

/// A year in which less than the Pillar 3a maximum was paid in.
class Pillar3aGap {
  const Pillar3aGap({
    required this.year,
    required this.maximum,
    required this.paid,
  });

  final int year;
  final Money maximum;
  final Money paid;

  Money get gap => paid.compareTo(maximum) >= 0 ? Money.zero : maximum - paid;

  /// Last year in which the gap can still be filled.
  int get lastYear => year + Pillar3aCatchUpRules.yearsBack;
}

/// Retroactive Pillar 3a purchases, possible from 2026 (BVV 3, art. 7a).
abstract final class Pillar3aCatchUpRules {
  /// Only gaps from this year on can be filled.
  static const firstGapYear = 2025;

  /// A gap can be filled for ten years.
  static const yearsBack = 10;

  /// Small 3a maximum (people with a pension fund) per year; later years
  /// use the latest known amount.
  static const _smallMaximum = {
    2025: Money.cents(725800),
    2026: Money.cents(725800),
  };

  static Money smallMaximum(int year) {
    if (_smallMaximum[year] case final known?) return known;
    final latest = _smallMaximum.keys.reduce((a, b) => a > b ? a : b);
    return year > latest
        ? _smallMaximum[latest]!
        : _smallMaximum[_smallMaximum.keys.reduce((a, b) => a < b ? a : b)]!;
  }
}

/// What can be paid in retroactively this year, and on which conditions.
class Pillar3aCatchUpPlan {
  const Pillar3aCatchUpPlan({
    required this.year,
    required this.gaps,
    required this.currentMaximum,
    required this.paidThisYear,
  });

  /// [paidByYear] holds what was paid in each past year since
  /// [Pillar3aCatchUpRules.firstGapYear]; years missing count as nothing
  /// paid. Gaps are measured against the small maximum, which caps
  /// retroactive purchases for everyone.
  factory Pillar3aCatchUpPlan.build({
    required int year,
    required Map<int, Money> paidByYear,
    required Money currentMaximum,
    required Money paidThisYear,
  }) {
    final first = year - Pillar3aCatchUpRules.yearsBack >
            Pillar3aCatchUpRules.firstGapYear
        ? year - Pillar3aCatchUpRules.yearsBack
        : Pillar3aCatchUpRules.firstGapYear;
    return Pillar3aCatchUpPlan(
      year: year,
      currentMaximum: currentMaximum,
      paidThisYear: paidThisYear,
      gaps: [
        for (var gapYear = first; gapYear < year; gapYear++)
          Pillar3aGap(
            year: gapYear,
            maximum: Pillar3aCatchUpRules.smallMaximum(gapYear),
            paid: paidByYear[gapYear] ?? Money.zero,
          ),
      ],
    );
  }

  final int year;
  final List<Pillar3aGap> gaps;
  final Money currentMaximum;
  final Money paidThisYear;

  Money get totalGap => Money.sum(gaps.map((gap) => gap.gap));

  /// What still has to go in for this year before a purchase is allowed.
  Money get currentYearRoom => paidThisYear.compareTo(currentMaximum) >= 0
      ? Money.zero
      : currentMaximum - paidThisYear;

  /// A purchase needs this year's maximum to be paid in first.
  bool get currentYearFull => currentYearRoom.isZero;

  /// At most the small maximum of this year, across all gaps.
  Money get purchasableThisYear {
    final cap = Pillar3aCatchUpRules.smallMaximum(year);
    return totalGap.compareTo(cap) > 0 ? cap : totalGap;
  }

  /// Rough tax saving of the purchase at [marginalRate].
  Money taxSaving(double marginalRate) =>
      Money.cents((purchasableThisYear.cents * marginalRate).round());

  /// Payments must arrive in the year to count for it.
  DateTime get deadline => DateTime(year, 12, 31);
}
