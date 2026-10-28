import 'package:finora/domain/models.dart';

/// Swiss basic health insurance (KVG/LAMal) rules for adults.
abstract final class SwissHealthInsuranceRules {
  /// Deductibles an adult can choose, in francs.
  static const adultDeductibles = [300, 500, 1000, 1500, 2000, 2500];

  /// After the deductible, 10 % of the costs are paid by the insured…
  static const coPaymentRate = .1;

  /// …up to CHF 700 a year.
  static const coPaymentCap = Money.cents(70000);

  /// A higher deductible lowers the premium by at most 70 % of the extra
  /// risk taken (KVV, art. 95). Insurers may give less.
  static const maxDiscountShare = .7;

  /// A new deductible or insurer for next year must reach the insurer by
  /// 30 November.
  static DateTime changeDeadline(DateTime now) => DateTime(now.year, 11, 30);
}

/// What one deductible costs in a year with the expected medical costs.
class DeductibleOption {
  const DeductibleOption({
    required this.deductible,
    required this.yearlyPremium,
    required this.outOfPocket,
  });

  /// In whole francs.
  final int deductible;
  final Money yearlyPremium;
  final Money outOfPocket;

  Money get total => yearlyPremium + outOfPocket;

  /// The most a bad year can cost: premium, deductible and the full
  /// co-payment.
  Money get worstCase =>
      yearlyPremium +
      Money.cents(deductible * 100) +
      SwissHealthInsuranceRules.coPaymentCap;
}

/// Every adult deductible compared with the current one.
class DeductibleComparison {
  const DeductibleComparison({
    required this.options,
    required this.currentDeductible,
  });

  /// Estimates the premium of each deductible from the current one, with
  /// the largest discount the law allows.
  factory DeductibleComparison.estimate({
    required Money monthlyPremium,
    required int currentDeductible,
    required Money expectedCosts,
  }) {
    int discount(int deductible) =>
        ((deductible - 300) * 100 * SwissHealthInsuranceRules.maxDiscountShare).round();
    final basePremium =
        (monthlyPremium * 12).cents + discount(currentDeductible);
    final costs = expectedCosts.cents < 0 ? 0 : expectedCosts.cents;

    Money outOfPocket(int deductible) {
      final threshold = deductible * 100;
      if (costs <= threshold) return Money.cents(costs);
      final coPayment = ((costs - threshold) * SwissHealthInsuranceRules.coPaymentRate).round();
      return Money.cents(
        threshold +
            (coPayment < SwissHealthInsuranceRules.coPaymentCap.cents
                ? coPayment
                : SwissHealthInsuranceRules.coPaymentCap.cents),
      );
    }

    return DeductibleComparison(
      currentDeductible: currentDeductible,
      options: [
        for (final deductible in SwissHealthInsuranceRules.adultDeductibles)
          DeductibleOption(
            deductible: deductible,
            yearlyPremium: Money.cents(
              basePremium - discount(deductible) < 0
                  ? 0
                  : basePremium - discount(deductible),
            ),
            outOfPocket: outOfPocket(deductible),
          ),
      ],
    );
  }

  final List<DeductibleOption> options;
  final int currentDeductible;

  /// Cheapest total; on a tie the lower deductible, which carries less
  /// risk.
  DeductibleOption get best => options.reduce(
    (a, b) => b.total.cents < a.total.cents ? b : a,
  );

  DeductibleOption get current => options.firstWhere(
    (option) => option.deductible == currentDeductible,
    orElse: () => options.first,
  );

  /// What switching to [best] saves in a year like the expected one.
  Money get yearlySaving => current.total - best.total;
}
