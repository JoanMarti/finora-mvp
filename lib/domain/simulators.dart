import 'dart:math' as math;

import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';

// -----------------------------------------------------------------------------
// Home affordability
// -----------------------------------------------------------------------------

/// Swiss lending rules of thumb used by banks to check a home purchase.
abstract final class SwissMortgageRules {
  /// At least 20 % of the price must be equity...
  static const minEquityShare = .2;

  /// ...of which at least 10 % "hard" equity, not from the pension fund.
  static const minHardEquityShare = .1;

  /// The part of the mortgage above two thirds of the price must be paid
  /// down within 15 years.
  static const firstMortgageShare = 2 / 3;
  static const amortisationYears = 15;

  /// Affordability is tested with 5 % imputed interest and 1 % of the
  /// price for upkeep; with amortisation it must stay within a third of
  /// gross income.
  static const imputedInterest = .05;
  static const upkeep = .01;
  static const maxCostShare = 1 / 3;
}

enum AffordabilityLimit { equity, hardEquity, income }

/// What a purchase at a given price would mean.
class PurchaseCheck {
  const PurchaseCheck({
    required this.price,
    required this.equityUsed,
    required this.mortgage,
    required this.yearlyCost,
    required this.costShare,
  });

  final Money price;
  final Money equityUsed;
  final Money mortgage;

  /// Imputed interest, upkeep and amortisation per year.
  final Money yearlyCost;

  /// [yearlyCost] as a share of gross income.
  final double costShare;

  Money get monthlyCost => yearlyCost * (1 / 12);
  double get loanToValue =>
      price.isZero ? 0 : mortgage.cents / price.cents;
}

class HomeAffordability {
  const HomeAffordability({
    required this.grossYearlyIncome,
    required this.cashEquity,
    required this.pillar3a,
    required this.pensionFundWithdrawal,
  });

  final Money grossYearlyIncome;

  /// Savings and other free assets brought in (hard equity).
  final Money cashEquity;

  /// Pillar 3a can be withdrawn for owner-occupied property and counts as
  /// hard equity.
  final Money pillar3a;

  /// Advance withdrawal from the pension fund; it counts as equity, but not
  /// as hard equity.
  final Money pensionFundWithdrawal;

  Money get hardEquity => cashEquity + pillar3a;
  Money get equity => hardEquity + pensionFundWithdrawal;

  /// Yearly cost at [price], using all available equity.
  PurchaseCheck check(Money price) {
    final equityUsed = equity.cents > price.cents ? price : equity;
    final mortgage = price - equityUsed;
    final firstMortgage = price * SwissMortgageRules.firstMortgageShare;
    final second = mortgage.cents > firstMortgage.cents
        ? mortgage - firstMortgage
        : Money.zero;
    final yearly =
        mortgage * SwissMortgageRules.imputedInterest +
        price * SwissMortgageRules.upkeep +
        second * (1 / SwissMortgageRules.amortisationYears);
    return PurchaseCheck(
      price: price,
      equityUsed: equityUsed,
      mortgage: mortgage,
      yearlyCost: yearly,
      costShare: grossYearlyIncome.isZero
          ? double.infinity
          : yearly.cents / grossYearlyIncome.cents,
    );
  }

  bool fits(Money price) =>
      check(price).costShare <= SwissMortgageRules.maxCostShare + 1e-9;

  /// Highest price allowed by income alone (cost grows with the price, so a
  /// bisection finds it).
  Money get _incomeLimit {
    if (grossYearlyIncome.isZero) return Money.zero;
    var low = 0;
    var high = 1000000000; // CHF 10 million in cents
    while (high - low > 100000) {
      final middle = (low + high) ~/ 2;
      if (fits(Money.cents(middle))) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return Money.cents(low);
  }

  /// Highest price, rounded down to CHF 1,000, and what limits it.
  (Money, AffordabilityLimit) get maxPrice {
    final byEquity = equity * (1 / SwissMortgageRules.minEquityShare);
    final byHardEquity = hardEquity * (1 / SwissMortgageRules.minHardEquityShare);
    final byIncome = _incomeLimit;
    final candidates = [
      (byEquity, AffordabilityLimit.equity),
      (byHardEquity, AffordabilityLimit.hardEquity),
      (byIncome, AffordabilityLimit.income),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final (price, limit) = candidates.first;
    return (Money.cents(price.cents ~/ 100000 * 100000), limit);
  }

  /// Gross income needed for [price] to pass the one-third test.
  Money incomeNeededFor(Money price) =>
      check(price).yearlyCost * (1 / SwissMortgageRules.maxCostShare);

  /// Equity needed for [price]: 20 % of the price.
  Money equityNeededFor(Money price) =>
      price * SwissMortgageRules.minEquityShare;
}

// -----------------------------------------------------------------------------
// Tax savings: Pillar 3a and pension fund buy-ins
// -----------------------------------------------------------------------------

class TaxSavingsResult {
  const TaxSavingsResult({
    required this.pillar3aContribution,
    required this.buyIn,
    required this.marginalRate,
    required this.extraMonthlyPension,
  });

  final Money pillar3aContribution;
  final Money buyIn;

  /// Share of an extra franc of income taken by tax (federal, cantonal,
  /// communal), between 0 and 1.
  final double marginalRate;

  /// Pension added at retirement by the buy-in.
  final Money extraMonthlyPension;

  Money get deductions => pillar3aContribution + buyIn;
  Money get taxSaving => deductions * marginalRate;
  Money get netCost => deductions - taxSaving;
}

abstract final class TaxSavings {
  /// Rough marginal rates are between 15 % and 40 % in Switzerland; the
  /// user should take theirs from the last assessment or the federal tax
  /// calculator.
  static const minRate = .1;
  static const maxRate = .45;
  static const defaultRate = .25;

  /// Buy-ins can only be withdrawn as a lump sum after three years.
  static const buyInLockYears = 3;

  static TaxSavingsResult simulate({
    required Money pillar3aContribution,
    required Money buyIn,
    required double marginalRate,
    required int yearsToRetirement,
    SwissPensionRules rules = SwissPensionRules.y2026,
  }) {
    final grown =
        buyIn * math.pow(1 + rules.bvgMinimumInterest, yearsToRetirement);
    return TaxSavingsResult(
      pillar3aContribution: pillar3aContribution,
      buyIn: buyIn,
      marginalRate: marginalRate.clamp(0.0, 1.0).toDouble(),
      extraMonthlyPension: grown * (rules.bvgConversionRate / 12),
    );
  }
}
