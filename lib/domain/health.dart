import 'dart:math' as math;

import 'package:finora/domain/models.dart';

/// The areas of the financial health check, in display order.
enum HealthFactorKind {
  emergencyFund,
  savingsRate,
  pillar3a,
  housing,
  retirement,
  fixedCosts;

  /// Relative weight in the overall score.
  int get weight => switch (this) {
    HealthFactorKind.emergencyFund => 20,
    HealthFactorKind.savingsRate => 20,
    HealthFactorKind.pillar3a => 15,
    HealthFactorKind.housing => 15,
    HealthFactorKind.retirement => 20,
    HealthFactorKind.fixedCosts => 10,
  };
}

enum HealthStatus { good, fair, attention, missingData }

/// One scored area. [score] is between 0 and 1, or `null` when Finora lacks
/// the data to judge it (the factor then only suggests what to add).
class HealthFactor {
  const HealthFactor({
    required this.kind,
    required this.score,
    required this.route,
    this.ratio,
    this.secondRatio,
    this.amount,
    this.target,
    this.isExample = false,
  });

  final HealthFactorKind kind;
  final double? score;

  /// Where the user can act on this factor.
  final String route;

  /// The main measured value (months, a rate or a coverage share).
  final double? ratio;

  /// A second value where the factor needs one (affordability for housing).
  final double? secondRatio;
  final Money? amount;
  final Money? target;

  /// Based on Finora's example figures rather than the user's own.
  final bool isExample;

  HealthStatus get status {
    final value = score;
    if (value == null) return HealthStatus.missingData;
    if (value >= .8) return HealthStatus.good;
    if (value >= .5) return HealthStatus.fair;
    return HealthStatus.attention;
  }
}

/// Swiss rules of thumb used by the health check. They are the yardsticks
/// banks and advisers commonly apply, not legal limits for the user.
abstract final class SwissHealthRules {
  /// Banks lend at most 80 % of a property's value...
  static const maxLoanToValue = .8;

  /// ...and the second mortgage above two thirds must be paid down within
  /// 15 years.
  static const firstMortgageShare = 2 / 3;

  /// Affordability test: imputed interest of 5 % on the mortgage plus 1 % of
  /// the property value for upkeep should stay within a third of gross
  /// income.
  static const imputedInterest = .05;
  static const upkeep = .01;
  static const maxHousingCostShare = 1 / 3;

  /// A savings rate of 20 % counts as fully healthy.
  static const goodSavingsRate = .2;

  /// Recurring bills up to half of spending are comfortable; from 70 % on
  /// there is little room to manoeuvre.
  static const comfortableFixedShare = .5;
  static const tightFixedShare = .7;
}

/// What the health check needs, gathered by the application layer.
class HealthInput {
  const HealthInput({
    required this.overview,
    required this.targets,
    required this.monthlyIncome,
    required this.savingsRate,
    required this.fixedCostShare,
    required this.mortgageDebt,
    required this.propertyValue,
    required this.retirementCoverage,
    required this.retirementIsExample,
    required this.hasPillar3a,
  });

  final FinancialOverview overview;
  final WealthTargets targets;
  final Money monthlyIncome;
  final double savingsRate;
  final double fixedCostShare;
  final Money mortgageDebt;
  final Money propertyValue;
  final double retirementCoverage;
  final bool retirementIsExample;
  final bool hasPillar3a;
}

class FinancialHealth {
  const FinancialHealth({required this.factors});

  factory FinancialHealth.of(HealthInput input) {
    double clamp01(double value) => value.clamp(0.0, 1.0).toDouble();
    final overview = input.overview;
    final factors = <HealthFactor>[];

    // 1. Emergency fund: months of spending in savings accounts.
    final spending = overview.monthlySpending;
    final months = spending.isZero
        ? null
        : overview.savings.cents / spending.cents;
    factors.add(
      HealthFactor(
        kind: HealthFactorKind.emergencyFund,
        score: months == null
            ? null
            : clamp01(months / input.targets.safetyBufferMonths),
        ratio: months,
        amount: overview.savings,
        target: spending * input.targets.safetyBufferMonths,
        route: '/goals',
      ),
    );

    // 2. Savings rate of the everyday accounts.
    factors.add(
      HealthFactor(
        kind: HealthFactorKind.savingsRate,
        score: input.monthlyIncome.isZero
            ? null
            : clamp01(input.savingsRate / SwissHealthRules.goodSavingsRate),
        ratio: input.savingsRate,
        route: '/analysis',
      ),
    );

    // 3. Pillar 3a used this year.
    final limit = input.targets.pillar3aAnnualLimit;
    final paid = overview.pillar3aContributionsThisYear;
    factors.add(
      HealthFactor(
        kind: HealthFactorKind.pillar3a,
        score: limit.isZero ? null : clamp01(paid.cents / limit.cents),
        ratio: limit.isZero ? null : paid.cents / limit.cents,
        amount: paid,
        target: limit,
        route: input.hasPillar3a ? '/retirement' : '/offers',
      ),
    );

    // 4. Housing: only when there is a mortgage. Needs the property value.
    if (!input.mortgageDebt.isZero) {
      if (input.propertyValue.isZero) {
        factors.add(
          HealthFactor(
            kind: HealthFactorKind.housing,
            score: null,
            amount: input.mortgageDebt,
            route: '/assets',
          ),
        );
      } else {
        final ltv = input.mortgageDebt.cents / input.propertyValue.cents;
        final yearlyIncome = input.monthlyIncome * 12;
        final housingCost =
            input.mortgageDebt * SwissHealthRules.imputedInterest +
            input.propertyValue * SwissHealthRules.upkeep;
        final affordability = yearlyIncome.isZero
            ? null
            : housingCost.cents / yearlyIncome.cents;
        final ltvScore = ltv <= SwissHealthRules.firstMortgageShare
            ? 1.0
            : ltv <= SwissHealthRules.maxLoanToValue
            ? .6
            : .2;
        final affordabilityScore = affordability == null
            ? 1.0
            : affordability <= SwissHealthRules.maxHousingCostShare
            ? 1.0
            : affordability <= .38
            ? .6
            : .2;
        factors.add(
          HealthFactor(
            kind: HealthFactorKind.housing,
            score: math.min(ltvScore, affordabilityScore),
            ratio: ltv,
            secondRatio: affordability,
            amount: input.mortgageDebt,
            target: input.propertyValue,
            route: '/offers',
          ),
        );
      }
    }

    // 5. Retirement: projected income against the user's target.
    factors.add(
      HealthFactor(
        kind: HealthFactorKind.retirement,
        score: clamp01(input.retirementCoverage),
        ratio: input.retirementCoverage,
        isExample: input.retirementIsExample,
        route: '/retirement',
      ),
    );

    // 6. Fixed costs: how much of spending is already committed.
    final share = input.fixedCostShare;
    factors.add(
      HealthFactor(
        kind: HealthFactorKind.fixedCosts,
        score: spending.isZero
            ? null
            : share <= SwissHealthRules.comfortableFixedShare
            ? 1.0
            : clamp01(
                1 -
                    .8 *
                        (share - SwissHealthRules.comfortableFixedShare) /
                        (SwissHealthRules.tightFixedShare -
                            SwissHealthRules.comfortableFixedShare),
              ),
        ratio: share,
        route: '/analysis',
      ),
    );

    return FinancialHealth(factors: factors);
  }

  final List<HealthFactor> factors;

  /// Weighted score from 0 to 100 over the factors that could be judged.
  int get score {
    var weighted = 0.0;
    var weights = 0;
    for (final factor in factors) {
      final value = factor.score;
      if (value == null) continue;
      weighted += value * factor.kind.weight;
      weights += factor.kind.weight;
    }
    return weights == 0 ? 0 : (weighted / weights * 100).round();
  }

  HealthStatus get status => score >= 80
      ? HealthStatus.good
      : score >= 50
      ? HealthStatus.fair
      : HealthStatus.attention;

  /// The factor where acting gains the most points, or one with missing
  /// data when everything else is already good.
  HealthFactor? get nextStep {
    HealthFactor? best;
    var bestGain = 0.0;
    for (final factor in factors) {
      final value = factor.score;
      if (value == null) continue;
      final gain = (1 - value) * factor.kind.weight;
      if (gain > bestGain + 1e-9) {
        best = factor;
        bestGain = gain;
      }
    }
    if (best != null && bestGain >= 2) return best;
    return factors
        .where((factor) => factor.status == HealthStatus.missingData)
        .firstOrNull;
  }
}
