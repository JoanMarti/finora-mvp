import 'dart:math' as math;

import 'package:finora/domain/models.dart';

/// Families of services a partner could offer.
enum OpportunityCategory { insurance, banking, pensions, mortgage, telecom, budget }

/// Each kind is one explainable rule in [OpportunityEngine].
enum OpportunityKind {
  healthInsuranceSwitch,
  insuranceReview,
  idleCash,
  pillar3aRoom,
  pillar3aOpen,
  mortgageRenewal,
  cardFees,
  telecomPlan,
  subscriptionsReview,
  bankFees,
}

/// How Finora would be paid if the user continues with a partner. It drives
/// the disclosure shown to the user and the business reporting; it never
/// affects which opportunities are shown or their order.
enum RevenueModel {
  /// Fixed fee per qualified lead or signed contract.
  leadFee,

  /// Share of the partner's commission on a concluded contract.
  commission,

  /// Fee per opened account or product.
  affiliate,

  /// No partner: the opportunity only helps the user.
  none,
}

/// A concrete, data-backed way for the user to save money.
class Opportunity {
  const Opportunity({
    required this.kind,
    required this.category,
    required this.revenue,
    required this.priority,
    this.savingLow,
    this.savingHigh,
    this.amount,
    this.subject,
    this.count,
    this.percent,
    this.deadline,
  });

  final OpportunityKind kind;
  final OpportunityCategory category;
  final RevenueModel revenue;

  /// Higher shows first. Deadlines and size of the saving decide it.
  final int priority;

  /// Estimated yearly saving range; `null` when it cannot be estimated.
  final Money? savingLow;
  final Money? savingHigh;

  /// Evidence used in the explanation ("You pay CHF 348 a month to …").
  final Money? amount;
  final String? subject;
  final int? count;
  final int? percent;

  /// Last useful day to act, if any.
  final DateTime? deadline;

  bool get isSponsored => revenue != RevenueModel.none;

  /// Stable id used to remember dismissals.
  String get id => kind.name;
}

/// Market facts the rules rely on. Updated once a year.
class SwissMarketFacts {
  const SwissMarketFacts({
    this.healthPremiumIncreasePercent = 5,
    this.healthSwitchDeadlineMonth = 11,
    this.healthSwitchDeadlineDay = 30,
    this.pillar3aLimit = const Money.cents(725800),
  });

  /// Average basic health insurance premium increase announced for 2027.
  final int healthPremiumIncreasePercent;

  /// Basic insurance can be cancelled until 30 November.
  final int healthSwitchDeadlineMonth;
  final int healthSwitchDeadlineDay;
  final Money pillar3aLimit;

  static const current = SwissMarketFacts();
}

/// Everything the rules look at. All of it already lives in the app; nothing
/// is sent anywhere to compute opportunities.
class OpportunityInput {
  const OpportunityInput({
    required this.accounts,
    required this.analytics,
    required this.pillar3aContributionsThisYear,
    required this.now,
    this.facts = SwissMarketFacts.current,
  });

  final List<FinancialAccount> accounts;
  final Map<String, AccountAnalytics> analytics;
  final Money pillar3aContributionsThisYear;
  final DateTime now;
  final SwissMarketFacts facts;
}

/// Turns account data into savings opportunities with transparent,
/// conservative estimates. Every rule is a pure function so it can be
/// tested and explained.
abstract final class OpportunityEngine {
  static List<Opportunity> detect(OpportunityInput input) {
    final found = <Opportunity>[
      ?_healthInsuranceSwitch(input),
      ?_insuranceReview(input),
      ?_idleCash(input),
      ?_pillar3a(input),
      ?_mortgageRenewal(input),
      ?_cardFees(input),
      ?_telecomPlan(input),
      ?_subscriptionsReview(input),
      ?_bankFees(input),
    ];
    found.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      return (b.savingHigh ?? Money.zero).compareTo(a.savingHigh ?? Money.zero);
    });
    return found;
  }

  /// Rounds to the nearest CHF 10 so estimates do not look falsely precise.
  static Money _round(Money money) =>
      Money.cents((money.cents / 1000).round() * 1000);

  static Iterable<RecurringPayment> _bills(OpportunityInput input) =>
      input.analytics.values.expand((item) => item.recurringPayments);

  static Iterable<FinancialAccount> _ofType(
    OpportunityInput input,
    FinancialProductType type,
  ) => input.accounts.where((account) => account.type == type);

  /// During the switching season (September to 30 November) a health
  /// insurance premium found in the bills suggests comparing offers.
  static Opportunity? _healthInsuranceSwitch(OpportunityInput input) {
    final premium = _bills(
      input,
    ).where((bill) => bill.category == BillCategory.healthInsurance).firstOrNull;
    if (premium == null) return null;
    final facts = input.facts;
    final deadline = DateTime(
      input.now.year,
      facts.healthSwitchDeadlineMonth,
      facts.healthSwitchDeadlineDay,
    );
    final inSeason = input.now.month >= 9 && !input.now.isAfter(deadline);
    if (!inSeason) return null;
    final yearly = premium.amount.abs() * 12;
    return Opportunity(
      kind: OpportunityKind.healthInsuranceSwitch,
      category: OpportunityCategory.insurance,
      revenue: RevenueModel.leadFee,
      priority: 100,
      savingLow: _round(yearly * .05),
      savingHigh: _round(yearly * .15),
      amount: premium.amount.abs(),
      subject: premium.merchant,
      percent: facts.healthPremiumIncreasePercent,
      deadline: deadline,
    );
  }

  /// Two or more insurance bills: a coverage check can find overlaps.
  static Opportunity? _insuranceReview(OpportunityInput input) {
    final insurance = _bills(input).where((bill) => bill.isInsurance).toList();
    if (insurance.length < 2) return null;
    final monthly = Money.sum(insurance.map((bill) => bill.amount.abs()));
    return Opportunity(
      kind: OpportunityKind.insuranceReview,
      category: OpportunityCategory.insurance,
      revenue: RevenueModel.commission,
      priority: 40,
      savingLow: const Money.cents(42000),
      savingHigh: const Money.cents(84000),
      amount: monthly,
      count: insurance.length,
    );
  }

  /// Cash above three months of spending left in current accounts.
  static Opportunity? _idleCash(OpportunityInput input) {
    final current = _ofType(input, FinancialProductType.currentAccount).toList();
    if (current.isEmpty) return null;
    final balance = Money.sum(current.map((account) => account.balance));
    final spending = Money.sum(
      current.map(
        (account) =>
            input.analytics[account.id]?.monthlySpending ?? Money.zero,
      ),
    );
    final excess = balance - spending * 3;
    if (excess.cents < 500000) return null;
    return Opportunity(
      kind: OpportunityKind.idleCash,
      category: OpportunityCategory.banking,
      revenue: RevenueModel.affiliate,
      priority: 30,
      // Rate gap between a current account (0 %) and a savings account.
      savingLow: _round(excess * .004),
      savingHigh: _round(excess * .008),
      amount: excess,
    );
  }

  /// Unused Pillar 3a room, or no Pillar 3a at all while earning a salary.
  static Opportunity? _pillar3a(OpportunityInput input) {
    final limit = input.facts.pillar3aLimit;
    final hasPillar3a = input.accounts.any(
      (account) => account.type.isRetirement,
    );
    final hasSalary = input.analytics.values.any(
      (item) => !item.monthlyIncome.isZero,
    );
    final yearEnd = DateTime(input.now.year, 12, 31);
    if (!hasPillar3a) {
      if (!hasSalary) return null;
      return Opportunity(
        kind: OpportunityKind.pillar3aOpen,
        category: OpportunityCategory.pensions,
        revenue: RevenueModel.affiliate,
        priority: 60,
        // Tax saved at an illustrative 20–30 % marginal rate.
        savingLow: _round(limit * .2),
        savingHigh: _round(limit * .3),
        amount: limit,
        deadline: yearEnd,
      );
    }
    final room = limit - input.pillar3aContributionsThisYear;
    if (room.cents < 50000) return null;
    final lastQuarter = input.now.month >= 10;
    return Opportunity(
      kind: OpportunityKind.pillar3aRoom,
      category: OpportunityCategory.pensions,
      revenue: RevenueModel.affiliate,
      priority: lastQuarter ? 90 : 35,
      savingLow: _round(room * .2),
      savingHigh: _round(room * .3),
      amount: room,
      deadline: yearEnd,
    );
  }

  /// A mortgage: a 0.1–0.3 point better rate on renewal pays every year.
  static Opportunity? _mortgageRenewal(OpportunityInput input) {
    final mortgages = _ofType(input, FinancialProductType.mortgage).toList();
    if (mortgages.isEmpty) return null;
    final debt = Money.sum(mortgages.map((account) => account.balance)).abs();
    return Opportunity(
      kind: OpportunityKind.mortgageRenewal,
      category: OpportunityCategory.mortgage,
      revenue: RevenueModel.commission,
      priority: 50,
      savingLow: _round(debt * .001),
      savingHigh: _round(debt * .003),
      amount: debt,
    );
  }

  /// A credit card: fee-free cards save annual and foreign-currency fees.
  static Opportunity? _cardFees(OpportunityInput input) {
    final cards = _ofType(input, FinancialProductType.creditCard).toList();
    if (cards.isEmpty) return null;
    return Opportunity(
      kind: OpportunityKind.cardFees,
      category: OpportunityCategory.banking,
      revenue: RevenueModel.affiliate,
      priority: 20,
      savingLow: const Money.cents(5000),
      savingHigh: const Money.cents(15000),
      subject: cards.first.name,
    );
  }

  /// Phone & internet above CHF 60 a month.
  static Opportunity? _telecomPlan(OpportunityInput input) {
    final bill = _bills(input)
        .where((item) => item.category == BillCategory.phoneInternet)
        .where((item) => item.amount.abs().cents > 6000)
        .firstOrNull;
    if (bill == null) return null;
    final yearly = bill.amount.abs() * 12;
    return Opportunity(
      kind: OpportunityKind.telecomPlan,
      category: OpportunityCategory.telecom,
      revenue: RevenueModel.affiliate,
      priority: 25,
      savingLow: _round(yearly * .2),
      savingHigh: _round(yearly * .4),
      amount: bill.amount.abs(),
      subject: bill.merchant,
    );
  }

  /// Two or more streaming or membership subscriptions. No partner: this
  /// one only helps the user cancel what they do not use.
  static Opportunity? _subscriptionsReview(OpportunityInput input) {
    final subscriptions = _bills(input)
        .where(
          (bill) =>
              bill.category == BillCategory.streaming ||
              bill.category == BillCategory.membership,
        )
        .toList();
    if (subscriptions.length < 2) return null;
    final yearly = Money.sum(
      subscriptions.map((bill) => bill.amount.abs() * 12),
    );
    final cheapest = subscriptions
        .map((bill) => bill.amount.abs() * 12)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    return Opportunity(
      kind: OpportunityKind.subscriptionsReview,
      category: OpportunityCategory.budget,
      revenue: RevenueModel.none,
      priority: 45,
      savingLow: _round(cheapest),
      savingHigh: _round(yearly * .5),
      amount: yearly,
      count: subscriptions.length,
    );
  }

  /// Current accounts at several banks each tend to charge fees.
  static Opportunity? _bankFees(OpportunityInput input) {
    final banks = _ofType(input, FinancialProductType.currentAccount)
        .map((account) => account.institutionId)
        .toSet();
    if (banks.length < 2) return null;
    final extra = banks.length - 1;
    return Opportunity(
      kind: OpportunityKind.bankFees,
      category: OpportunityCategory.banking,
      revenue: RevenueModel.affiliate,
      priority: 15,
      savingLow: Money.cents(6000 * extra),
      savingHigh: Money.cents(24000 * math.max(1, extra)),
      count: banks.length,
    );
  }
}
