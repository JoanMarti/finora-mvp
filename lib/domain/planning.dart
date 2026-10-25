import 'dart:math' as math;

import 'package:finora/domain/models.dart';

// -----------------------------------------------------------------------------
// Savings goals
// -----------------------------------------------------------------------------

/// A personal goal funded by one or more accounts, e.g. "Flat deposit".
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    this.deadline,
    this.accountIds = const {},
  });

  final String id;
  final String name;
  final Money target;

  /// Optional date by which the target should be reached.
  final DateTime? deadline;

  /// Accounts whose balances count towards the goal.
  final Set<String> accountIds;

  SavingsGoal copyWith({
    String? name,
    Money? target,
    DateTime? deadline,
    bool clearDeadline = false,
    Set<String>? accountIds,
  }) => SavingsGoal(
    id: id,
    name: name ?? this.name,
    target: target ?? this.target,
    deadline: clearDeadline ? null : deadline ?? this.deadline,
    accountIds: accountIds ?? this.accountIds,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'targetCents': target.cents,
    'deadline': deadline?.toIso8601String(),
    'accountIds': accountIds.toList(),
  };

  static SavingsGoal? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final cents = raw['targetCents'];
    if (id is! String || name is! String || cents is! num) return null;
    final deadline = raw['deadline'];
    return SavingsGoal(
      id: id,
      name: name,
      target: Money.cents(cents.toInt()),
      deadline: deadline is String ? DateTime.tryParse(deadline) : null,
      accountIds: {...?(raw['accountIds'] as List?)?.whereType<String>()},
    );
  }
}

/// Where a goal stands today.
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.saved,
    required this.monthlyNeeded,
    required this.monthsLeft,
  });

  /// Measures [goal] against the current [accounts]. Accounts that are no
  /// longer connected simply stop counting.
  factory GoalProgress.of(
    SavingsGoal goal,
    List<FinancialAccount> accounts,
    DateTime now,
  ) {
    final saved = Money.sum(
      accounts
          .where((account) => goal.accountIds.contains(account.id))
          .map((account) => account.balance),
    );
    final remaining = goal.target - saved;
    final deadline = goal.deadline;
    int? monthsLeft;
    Money? monthlyNeeded;
    if (deadline != null) {
      monthsLeft = math.max(
        0,
        (deadline.year - now.year) * 12 + deadline.month - now.month,
      );
      monthlyNeeded = remaining.cents <= 0
          ? Money.zero
          : remaining * (1 / math.max(1, monthsLeft));
    }
    return GoalProgress(
      goal: goal,
      saved: saved,
      monthlyNeeded: monthlyNeeded,
      monthsLeft: monthsLeft,
    );
  }

  final SavingsGoal goal;
  final Money saved;

  /// Amount to put aside each month to reach the goal on time; `null` when
  /// the goal has no deadline.
  final Money? monthlyNeeded;
  final int? monthsLeft;

  double get progress => goal.target.cents <= 0
      ? 1.0
      : (saved.cents / goal.target.cents).clamp(0.0, 1.0).toDouble();
  bool get isReached => saved.compareTo(goal.target) >= 0;
  Money get remaining =>
      isReached ? Money.zero : goal.target - saved;
}

// -----------------------------------------------------------------------------
// Retirement (three pillars)
// -----------------------------------------------------------------------------

/// Swiss pension parameters. Values are those in force for 2026; they are
/// grouped so a yearly update touches one place.
class SwissPensionRules {
  const SwissPensionRules({
    this.ahvMinimumMonthly = const Money.cents(126000),
    this.ahvMaximumMonthly = const Money.cents(252000),
    this.thirteenthAhvPension = true,
    this.bvgMinimumInterest = .0125,
    this.bvgConversionRate = .068,
    this.ordinaryRetirementAge = 65,
    this.pillar3aDrawdownYears = 20,
    this.ahvCoupleCapShare = 1.5,
  });

  /// Full-contribution single pension, AHV/AVS (CHF 1,260 – 2,520 a month).
  final Money ahvMinimumMonthly;
  final Money ahvMaximumMonthly;

  /// A 13th monthly AHV pension is paid every December from 2026.
  final bool thirteenthAhvPension;

  /// Minimum interest on mandatory BVG/LPP savings (1.25 % for 2026).
  final double bvgMinimumInterest;

  /// Legal minimum conversion rate on the mandatory part (6.8 %).
  final double bvgConversionRate;
  final int ordinaryRetirementAge;

  /// Years over which Pillar 3a capital is assumed to be spent.
  final int pillar3aDrawdownYears;

  /// Married couples' two AHV pensions together are capped at 150 % of the
  /// maximum single pension.
  final double ahvCoupleCapShare;

  static const y2026 = SwissPensionRules();

  /// Monthly AHV pension for an average yearly income, using the official
  /// pension formula and assuming a complete contribution record.
  Money ahvMonthlyPension(Money averageAnnualIncome) {
    final minimum = ahvMinimumMonthly.amount;
    final income = averageAnnualIncome.amount;
    final threshold = minimum * 12 * 3;
    final pension = income <= threshold
        ? .74 * minimum + 13 / 600 * income
        : 1.04 * minimum + 8 / 600 * income;
    final clamped = pension.clamp(minimum, ahvMaximumMonthly.amount);
    return Money(clamped.toDouble());
  }
}

/// What the user tells Finora about their retirement situation.
class RetirementProfile {
  const RetirementProfile({
    required this.birthYear,
    required this.annualSalary,
    required this.pensionFundBalance,
    required this.annualPensionFundCredits,
    this.annualPillar3aContribution = const Money.cents(725800),
    this.pillar3aReturn = .02,
    this.replacementTarget = .7,
  });

  /// Example profile shown until the user enters their own figures.
  static const demo = RetirementProfile(
    birthYear: 1988,
    annualSalary: Money.cents(11000000),
    pensionFundBalance: Money.cents(8500000),
    annualPensionFundCredits: Money.cents(980000),
  );

  final int birthYear;
  final Money annualSalary;

  /// Retirement savings shown on the pension fund certificate.
  final Money pensionFundBalance;

  /// Yearly savings credits (employee + employer) from the certificate.
  final Money annualPensionFundCredits;
  final Money annualPillar3aContribution;

  /// Assumed yearly return on Pillar 3a savings.
  final double pillar3aReturn;

  /// Share of today's salary the user wants in retirement.
  final double replacementTarget;

  RetirementProfile copyWith({
    int? birthYear,
    Money? annualSalary,
    Money? pensionFundBalance,
    Money? annualPensionFundCredits,
    Money? annualPillar3aContribution,
    double? pillar3aReturn,
    double? replacementTarget,
  }) => RetirementProfile(
    birthYear: birthYear ?? this.birthYear,
    annualSalary: annualSalary ?? this.annualSalary,
    pensionFundBalance: pensionFundBalance ?? this.pensionFundBalance,
    annualPensionFundCredits:
        annualPensionFundCredits ?? this.annualPensionFundCredits,
    annualPillar3aContribution:
        annualPillar3aContribution ?? this.annualPillar3aContribution,
    pillar3aReturn: pillar3aReturn ?? this.pillar3aReturn,
    replacementTarget: replacementTarget ?? this.replacementTarget,
  );

  Map<String, Object?> toJson() => {
    'birthYear': birthYear,
    'annualSalaryCents': annualSalary.cents,
    'pensionFundBalanceCents': pensionFundBalance.cents,
    'annualPensionFundCreditsCents': annualPensionFundCredits.cents,
    'annualPillar3aContributionCents': annualPillar3aContribution.cents,
    'pillar3aReturn': pillar3aReturn,
    'replacementTarget': replacementTarget,
  };

  static RetirementProfile? fromJson(Object? raw) {
    if (raw is! Map) return null;
    Money? money(String key) {
      final value = raw[key];
      return value is num ? Money.cents(value.toInt()) : null;
    }

    final birthYear = raw['birthYear'];
    final salary = money('annualSalaryCents');
    final balance = money('pensionFundBalanceCents');
    final credits = money('annualPensionFundCreditsCents');
    if (birthYear is! num ||
        salary == null ||
        balance == null ||
        credits == null) {
      return null;
    }
    return RetirementProfile(
      birthYear: birthYear.toInt(),
      annualSalary: salary,
      pensionFundBalance: balance,
      annualPensionFundCredits: credits,
      annualPillar3aContribution:
          money('annualPillar3aContributionCents') ??
          const Money.cents(725800),
      pillar3aReturn: (raw['pillar3aReturn'] as num?)?.toDouble() ?? .02,
      replacementTarget: (raw['replacementTarget'] as num?)?.toDouble() ?? .7,
    );
  }
}

/// Estimated monthly income in retirement, pillar by pillar.
class RetirementProjection {
  const RetirementProjection({
    required this.retirementYear,
    required this.yearsToRetirement,
    required this.ahvMonthly,
    required this.pensionFundCapital,
    required this.pensionFundMonthly,
    required this.pillar3aCapital,
    required this.pillar3aMonthly,
    required this.targetMonthly,
  });

  /// Projects [profile] forward. [pillar3aBalance] is today's total across
  /// the user's 3a accounts. All results are in today's francs (no
  /// inflation), which keeps the comparison with today's salary honest.
  factory RetirementProjection.of(
    RetirementProfile profile, {
    required Money pillar3aBalance,
    required DateTime now,
    SwissPensionRules rules = SwissPensionRules.y2026,
  }) {
    final retirementYear = profile.birthYear + rules.ordinaryRetirementAge;
    final years = math.max(0, retirementYear - now.year);

    Money grow(Money start, Money yearly, double rate) {
      if (years == 0) return start;
      final factor = math.pow(1 + rate, years).toDouble();
      final annuity = rate == 0 ? years.toDouble() : (factor - 1) / rate;
      return start * factor + yearly * annuity;
    }

    final pensionCapital = grow(
      profile.pensionFundBalance,
      profile.annualPensionFundCredits,
      rules.bvgMinimumInterest,
    );
    final pillarCapital = grow(
      pillar3aBalance,
      profile.annualPillar3aContribution,
      profile.pillar3aReturn,
    );
    final ahvMonthly = rules.ahvMonthlyPension(profile.annualSalary);

    return RetirementProjection(
      retirementYear: retirementYear,
      yearsToRetirement: years,
      // The 13th pension adds one monthly payment a year.
      ahvMonthly: rules.thirteenthAhvPension ? ahvMonthly * (13 / 12) : ahvMonthly,
      pensionFundCapital: pensionCapital,
      pensionFundMonthly: pensionCapital * (rules.bvgConversionRate / 12),
      pillar3aCapital: pillarCapital,
      pillar3aMonthly: pillarCapital * (1 / (rules.pillar3aDrawdownYears * 12)),
      targetMonthly: profile.annualSalary * (profile.replacementTarget / 12),
    );
  }

  final int retirementYear;
  final int yearsToRetirement;
  final Money ahvMonthly;
  final Money pensionFundCapital;
  final Money pensionFundMonthly;
  final Money pillar3aCapital;
  final Money pillar3aMonthly;
  final Money targetMonthly;

  Money get totalMonthly => ahvMonthly + pensionFundMonthly + pillar3aMonthly;

  /// Positive when projected income falls short of the target.
  Money get gapMonthly => targetMonthly - totalMonthly;
  bool get onTrack => gapMonthly.cents <= 0;

  double get coverage => targetMonthly.cents <= 0
      ? 1.0
      : totalMonthly.cents / targetMonthly.cents;
}

/// Alternative assumptions for the retirement projection (Finora Plus).
enum RetirementScenario {
  /// Pension funds often convert the whole capital at about 5 %, below the
  /// 6.8 % legal minimum that only covers the mandatory part; 3a returns
  /// 1.5 points lower.
  cautious,

  /// The user's own assumptions.
  base,

  /// Pension fund interest of 2 % and 3a returns 2 points higher.
  favourable,
}

extension RetirementScenarios on RetirementScenario {
  /// Projects [profile] under this scenario's assumptions.
  RetirementProjection project(
    RetirementProfile profile, {
    required Money pillar3aBalance,
    required DateTime now,
  }) {
    final (rules, pillarReturn) = switch (this) {
      RetirementScenario.cautious => (
        const SwissPensionRules(bvgConversionRate: .05),
        math.max(0.0, profile.pillar3aReturn - .015),
      ),
      RetirementScenario.base => (
        SwissPensionRules.y2026,
        profile.pillar3aReturn,
      ),
      RetirementScenario.favourable => (
        const SwissPensionRules(bvgMinimumInterest: .02),
        profile.pillar3aReturn + .02,
      ),
    };
    return RetirementProjection.of(
      profile.copyWith(pillar3aReturn: pillarReturn),
      pillar3aBalance: pillar3aBalance,
      now: now,
      rules: rules,
    );
  }
}

// -----------------------------------------------------------------------------
// Tax return summary
// -----------------------------------------------------------------------------

/// Figures a data source reports for one account and tax year.
class TaxAccountFigures {
  const TaxAccountFigures({
    required this.account,
    required this.closingBalance,
    this.income = Money.zero,
    this.interestPaid = Money.zero,
  });

  final FinancialAccount account;

  /// Balance on 31 December, or today for the running year.
  final Money closingBalance;

  /// Interest or dividends received during the year.
  final Money income;

  /// Debt interest paid during the year (mortgages, loans).
  final Money interestPaid;
}

class TaxYearData {
  const TaxYearData({
    required this.year,
    required this.asOf,
    required this.isComplete,
    required this.accounts,
    required this.pillar3aContributions,
  });

  final int year;

  /// 31 December for past years, today for the running year.
  final DateTime asOf;
  final bool isComplete;
  final List<TaxAccountFigures> accounts;
  final Money pillar3aContributions;
}

/// Groups a [TaxYearData] the way Swiss tax forms ask for it.
class TaxYearSummary {
  TaxYearSummary(this.data, {required Money pillar3aLimit})
    : bankAccounts = [
        for (final item in data.accounts)
          if (item.account.type.isCash) item,
      ],
      securities = [
        for (final item in data.accounts)
          if (item.account.type.isInvestment) item,
      ],
      debts = [
        for (final item in data.accounts)
          if (item.account.type.isLiability) item,
      ],
      pillar3aAccounts = [
        for (final item in data.accounts)
          if (item.account.type.isRetirement) item,
      ],
      pillar3aDeductible =
          data.pillar3aContributions.compareTo(pillar3aLimit) > 0
          ? pillar3aLimit
          : data.pillar3aContributions;

  final TaxYearData data;
  final List<TaxAccountFigures> bankAccounts;

  /// The securities list (Wertschriftenverzeichnis / état des titres).
  final List<TaxAccountFigures> securities;
  final List<TaxAccountFigures> debts;

  /// Shown for reference: Pillar 3a capital is not taxable wealth.
  final List<TaxAccountFigures> pillar3aAccounts;
  final Money pillar3aDeductible;

  static Money _sum(List<TaxAccountFigures> items, Money Function(TaxAccountFigures) pick) =>
      Money.sum(items.map(pick));

  Money get bankTotal => _sum(bankAccounts, (item) => item.closingBalance);
  Money get securitiesTotal => _sum(securities, (item) => item.closingBalance);

  /// Debt as a positive amount.
  Money get debtTotal => _sum(debts, (item) => item.closingBalance).abs();
  Money get taxableIncome => _sum(
    [...bankAccounts, ...securities],
    (item) => item.income,
  );
  Money get debtInterest => _sum(debts, (item) => item.interestPaid);
  Money get netWealth => bankTotal + securitiesTotal - debtTotal;
}
