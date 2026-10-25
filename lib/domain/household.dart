import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';

/// Married couples and registered partners share an AHV cap and are taxed
/// jointly; cohabiting partners are not.
enum Relationship { married, cohabiting }

/// How shared bills are divided.
enum SplitRule {
  /// In proportion to each partner's net income.
  byIncome,
  equal,
}

/// The partner's figures, entered by the user. Until partners can connect
/// their own banks (needs the backend), these are estimates.
class Household {
  const Household({
    required this.partnerName,
    required this.relationship,
    required this.partnerMonthlyIncome,
    this.partnerCash = Money.zero,
    this.partnerInvestments = Money.zero,
    this.partnerPillar3a = Money.zero,
    this.partnerDebts = Money.zero,
    this.partnerRetirement,
    this.splitRule = SplitRule.byIncome,
  });

  final String partnerName;
  final Relationship relationship;

  /// Net monthly income, used to split shared bills.
  final Money partnerMonthlyIncome;
  final Money partnerCash;
  final Money partnerInvestments;
  final Money partnerPillar3a;

  /// Outstanding debt as a positive amount.
  final Money partnerDebts;

  /// Pension details, for the couple's retirement projection.
  final RetirementProfile? partnerRetirement;
  final SplitRule splitRule;

  Money get partnerNetWorth =>
      partnerCash + partnerInvestments + partnerPillar3a - partnerDebts;

  Household copyWith({
    String? partnerName,
    Relationship? relationship,
    Money? partnerMonthlyIncome,
    Money? partnerCash,
    Money? partnerInvestments,
    Money? partnerPillar3a,
    Money? partnerDebts,
    RetirementProfile? partnerRetirement,
    SplitRule? splitRule,
  }) => Household(
    partnerName: partnerName ?? this.partnerName,
    relationship: relationship ?? this.relationship,
    partnerMonthlyIncome: partnerMonthlyIncome ?? this.partnerMonthlyIncome,
    partnerCash: partnerCash ?? this.partnerCash,
    partnerInvestments: partnerInvestments ?? this.partnerInvestments,
    partnerPillar3a: partnerPillar3a ?? this.partnerPillar3a,
    partnerDebts: partnerDebts ?? this.partnerDebts,
    partnerRetirement: partnerRetirement ?? this.partnerRetirement,
    splitRule: splitRule ?? this.splitRule,
  );

  Map<String, Object?> toJson() => {
    'partnerName': partnerName,
    'relationship': relationship.name,
    'partnerMonthlyIncome': partnerMonthlyIncome.cents,
    'partnerCash': partnerCash.cents,
    'partnerInvestments': partnerInvestments.cents,
    'partnerPillar3a': partnerPillar3a.cents,
    'partnerDebts': partnerDebts.cents,
    'partnerRetirement': partnerRetirement?.toJson(),
    'splitRule': splitRule.name,
  };

  static Household? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final relationship = Relationship.values
        .where((value) => value.name == raw['relationship'])
        .firstOrNull;
    final name = raw['partnerName'];
    if (relationship == null || name is! String) return null;
    Money money(String key) {
      final value = raw[key];
      return value is int ? Money.cents(value) : Money.zero;
    }

    return Household(
      partnerName: name,
      relationship: relationship,
      partnerMonthlyIncome: money('partnerMonthlyIncome'),
      partnerCash: money('partnerCash'),
      partnerInvestments: money('partnerInvestments'),
      partnerPillar3a: money('partnerPillar3a'),
      partnerDebts: money('partnerDebts'),
      partnerRetirement: RetirementProfile.fromJson(raw['partnerRetirement']),
      splitRule:
          SplitRule.values
              .where((value) => value.name == raw['splitRule'])
              .firstOrNull ??
          SplitRule.byIncome,
    );
  }
}

/// Combined picture of both partners.
class HouseholdSummary {
  const HouseholdSummary({
    required this.myNetWorth,
    required this.partnerNetWorth,
    required this.myIncome,
    required this.partnerIncome,
    required this.sharedBills,
    required this.splitRule,
  });

  factory HouseholdSummary.of(
    Household household, {
    required Money myNetWorth,
    required Money myMonthlyIncome,
    required Money sharedMonthlyBills,
  }) => HouseholdSummary(
    myNetWorth: myNetWorth,
    partnerNetWorth: household.partnerNetWorth,
    myIncome: myMonthlyIncome,
    partnerIncome: household.partnerMonthlyIncome,
    sharedBills: sharedMonthlyBills,
    splitRule: household.splitRule,
  );

  final Money myNetWorth;
  final Money partnerNetWorth;
  final Money myIncome;
  final Money partnerIncome;

  /// Recurring bills per month that the couple shares.
  final Money sharedBills;
  final SplitRule splitRule;

  Money get netWorth => myNetWorth + partnerNetWorth;
  Money get income => myIncome + partnerIncome;

  /// My share of the shared bills, between 0 and 1.
  double get myShare {
    if (splitRule == SplitRule.equal || income.isZero) return .5;
    return myIncome.cents / income.cents;
  }

  Money get myPart => sharedBills * myShare;
  Money get partnerPart => sharedBills - myPart;
}

/// Retirement income of a couple. For married couples and registered
/// partners the two AHV pensions together are capped at 150 % of the
/// maximum single pension.
class CoupleRetirement {
  const CoupleRetirement({
    required this.me,
    required this.partner,
    required this.ahvBeforeCap,
    required this.ahv,
  });

  factory CoupleRetirement.of(
    RetirementProjection me,
    RetirementProjection partner, {
    required Relationship relationship,
    SwissPensionRules rules = SwissPensionRules.y2026,
  }) {
    final combined = me.ahvMonthly + partner.ahvMonthly;
    // The projections already include the 13th pension, so the cap does
    // too.
    final cap =
        rules.ahvMaximumMonthly *
        (rules.ahvCoupleCapShare * (rules.thirteenthAhvPension ? 13 / 12 : 1));
    final capped = relationship == Relationship.married && combined.cents > cap.cents
        ? cap
        : combined;
    return CoupleRetirement(
      me: me,
      partner: partner,
      ahvBeforeCap: combined,
      ahv: capped,
    );
  }

  final RetirementProjection me;
  final RetirementProjection partner;
  final Money ahvBeforeCap;
  final Money ahv;

  bool get isCapped => ahv.cents < ahvBeforeCap.cents;
  Money get capReduction => ahvBeforeCap - ahv;

  Money get occupational => me.pensionFundMonthly + partner.pensionFundMonthly;
  Money get pillar3a => me.pillar3aMonthly + partner.pillar3aMonthly;
  Money get totalMonthly => ahv + occupational + pillar3a;
  Money get targetMonthly => me.targetMonthly + partner.targetMonthly;

  double get coverage => targetMonthly.cents <= 0
      ? 1.0
      : totalMonthly.cents / targetMonthly.cents;
}
