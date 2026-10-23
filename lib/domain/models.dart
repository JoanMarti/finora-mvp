/// Product families. Display names live in the localization layer
/// (`l10n/labels.dart`), never in the domain.
enum FinancialProductType {
  currentAccount,
  savings,
  investments,
  pillar3a,
  creditCard,
  mortgage;

  bool get isCash => this == currentAccount || this == savings;
  bool get isInvestment => this == investments;
  bool get isRetirement => this == pillar3a;
  bool get isLiability => this == creditCard || this == mortgage;

  /// Accounts that produce day-to-day transactions and cash-flow analytics.
  bool get hasTransactions => this == currentAccount || this == creditCard;
}

enum ConnectionStatus { connected, stale, actionRequired, manual }

/// How Finora receives data from an institution.
enum ConnectionMethod {
  /// Read-only bank data through SIX bLink.
  bLink,

  /// Read-only portfolio data through an OpenWealth API.
  openWealth,

  /// Values entered or uploaded by the user.
  manual,
}

/// An amount of money stored in minor units (Rappen for CHF) so that sums
/// never accumulate floating-point rounding errors.
class Money implements Comparable<Money> {
  const Money.cents(this.cents, {this.currency = 'CHF'});

  /// Convenience constructor for display-level values such as `Money(12.5)`.
  Money(double amount, {String currency = 'CHF'})
    : this.cents((amount * 100).round(), currency: currency);

  static const zero = Money.cents(0);

  final int cents;
  final String currency;

  double get amount => cents / 100;
  bool get isNegative => cents < 0;
  bool get isZero => cents == 0;

  Money abs() => Money.cents(cents.abs(), currency: currency);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money.cents(cents + other.cents, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money.cents(cents - other.cents, currency: currency);
  }

  Money operator -() => Money.cents(-cents, currency: currency);

  Money operator *(num factor) =>
      Money.cents((cents * factor).round(), currency: currency);

  static Money sum(Iterable<Money> values, {String currency = 'CHF'}) =>
      values.fold<Money>(
        Money.cents(0, currency: currency),
        (total, value) => total + value,
      );

  void _assertSameCurrency(Money other) {
    assert(
      other.currency == currency,
      'Cannot combine $currency with ${other.currency} without conversion.',
    );
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) =>
      other is Money && other.cents == cents && other.currency == currency;

  @override
  int get hashCode => Object.hash(cents, currency);

  @override
  String toString() => '$currency ${amount.toStringAsFixed(2)}';
}

class Institution {
  const Institution({
    required this.id,
    required this.name,
    required this.shortName,
    required this.colorValue,
    required this.connectionMethod,
    required this.productTypes,
  });
  final String id;
  final String name;
  final String shortName;
  final int colorValue;
  final ConnectionMethod connectionMethod;

  /// Product families this institution can contribute to an overview.
  final Set<FinancialProductType> productTypes;

  bool get isManual => connectionMethod == ConnectionMethod.manual;
}

class InstitutionConnection {
  const InstitutionConnection({
    required this.institutionId,
    required this.status,
    required this.lastSyncedAt,
  });
  final String institutionId;
  final ConnectionStatus status;
  final DateTime lastSyncedAt;
}

class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.type,
    required this.balance,
    required this.maskedIdentifier,
    required this.monthlyChange,
  });
  final String id;
  final String institutionId;
  final String name;
  final FinancialProductType type;

  /// Current balance. Liabilities (cards, mortgages) are negative.
  final Money balance;
  final String maskedIdentifier;

  /// Balance change since the start of the current month.
  final Money monthlyChange;
}

enum TransactionCategory {
  income,
  groceries,
  transport,
  utilities,
  shopping,
  insurance,
  dining,
  housing,
  other,
}

class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.accountId,
    required this.merchant,
    required this.category,
    required this.bookedAt,
    required this.amount,
  });
  final String id;
  final String accountId;
  final String merchant;
  final TransactionCategory category;
  final DateTime bookedAt;
  final Money amount;
}

class BalanceHistoryPoint {
  const BalanceHistoryPoint({required this.month, required this.balance});

  /// First day of the month this closing balance belongs to.
  final DateTime month;
  final Money balance;
}

class CashFlowPoint {
  const CashFlowPoint({
    required this.month,
    required this.income,
    required this.spending,
  });
  final DateTime month;
  final Money income;
  final Money spending;
}

enum BillCategory {
  healthInsurance,
  householdInsurance,
  phoneInternet,
  membership,
  streaming,
  electricity,
  radioTvFee;

  bool get isInsurance =>
      this == healthInsurance || this == householdInsurance;
}

enum BillCadence { monthly, monthlyEquivalent }

class RecurringPayment {
  const RecurringPayment({
    required this.merchant,
    required this.category,
    required this.amount,
    required this.cadence,
    required this.nextDueAt,
  });
  final String merchant;
  final BillCategory category;
  final Money amount;
  final BillCadence cadence;
  final DateTime nextDueAt;

  bool get isInsurance => category.isInsurance;
}

class SpendingCategory {
  const SpendingCategory({
    required this.category,
    required this.amount,
    required this.colorValue,
  });
  final TransactionCategory category;
  final Money amount;
  final int colorValue;
}

class AccountAnalytics {
  const AccountAnalytics({
    required this.monthlyIncome,
    required this.monthlySpending,
    required this.balanceHistory,
    required this.cashFlowHistory,
    required this.recurringPayments,
    required this.spendingCategories,
  });

  const AccountAnalytics.empty()
    : monthlyIncome = Money.zero,
      monthlySpending = Money.zero,
      balanceHistory = const [],
      cashFlowHistory = const [],
      recurringPayments = const [],
      spendingCategories = const [];

  final Money monthlyIncome;
  final Money monthlySpending;
  final List<BalanceHistoryPoint> balanceHistory;
  final List<CashFlowPoint> cashFlowHistory;
  final List<RecurringPayment> recurringPayments;
  final List<SpendingCategory> spendingCategories;

  bool get hasBalanceHistory => balanceHistory.length >= 2;
  bool get hasCashFlow => cashFlowHistory.isNotEmpty;

  Money get monthlyNet => monthlyIncome - monthlySpending;
  double get savingsRate =>
      monthlyIncome.isZero ? 0.0 : monthlyNet.cents / monthlyIncome.cents;
  Money get recurringTotal =>
      Money.sum(recurringPayments.map((payment) => payment.amount.abs()));
  List<RecurringPayment> get insurancePayments =>
      recurringPayments.where((payment) => payment.isInsurance).toList();
}

/// Net-worth snapshot derived from the user's accounts. It is never stored:
/// it is always recomputed from the accounts so the totals stay consistent.
class FinancialOverview {
  const FinancialOverview({
    required this.cash,
    required this.savings,
    required this.investments,
    required this.retirement,
    required this.liabilities,
    required this.history,
    required this.monthlySpending,
    required this.pillar3aContributionsThisYear,
  });

  factory FinancialOverview.fromAccounts(
    List<FinancialAccount> accounts, {
    List<BalanceHistoryPoint> history = const [],
    Money monthlySpending = Money.zero,
    Money pillar3aContributionsThisYear = Money.zero,
  }) {
    Money sumWhere(bool Function(FinancialProductType type) test) => Money.sum(
      accounts
          .where((account) => test(account.type))
          .map((account) => account.balance),
    );
    return FinancialOverview(
      cash: sumWhere((type) => type.isCash),
      savings: sumWhere((type) => type == FinancialProductType.savings),
      investments: sumWhere((type) => type.isInvestment),
      retirement: sumWhere((type) => type.isRetirement),
      liabilities: sumWhere((type) => type.isLiability).abs(),
      history: history,
      monthlySpending: monthlySpending,
      pillar3aContributionsThisYear: pillar3aContributionsThisYear,
    );
  }

  final Money cash;

  /// Part of [cash] held in savings accounts (the safety buffer).
  final Money savings;
  final Money investments;
  final Money retirement;

  /// Outstanding debt as a positive amount.
  final Money liabilities;

  /// Monthly net-worth closing values, oldest first.
  final List<BalanceHistoryPoint> history;

  /// Monthly spending across everyday accounts.
  final Money monthlySpending;
  final Money pillar3aContributionsThisYear;

  Money get assets => cash + investments + retirement;
  Money get total => assets - liabilities;
  bool get isEmpty => assets.isZero && liabilities.isZero;

  /// Share of total assets represented by [part], between 0 and 1.
  double share(Money part) =>
      assets.cents <= 0 ? 0.0 : part.cents / assets.cents;

  /// Change between the last two history points (0.031 = 3.1%).
  double? get monthlyChangeRate => _changeRate(2);

  /// Change across the whole history window.
  double? get periodChangeRate => _changeRate(history.length);

  Money get periodChange => history.length < 2
      ? Money.zero
      : history.last.balance - history.first.balance;

  double? _changeRate(int window) {
    if (history.length < 2 || window < 2) return null;
    final start = history[history.length - window].balance;
    if (start.cents == 0) return null;
    return (history.last.balance.cents - start.cents) / start.cents.abs();
  }
}

/// Personal targets used by the wealth plan. Defaults are deliberately simple
/// until the user can personalise them.
class WealthTargets {
  const WealthTargets({
    this.safetyBufferMonths = 6,
    this.longTermShare = .45,
    this.pillar3aAnnualLimit = const Money.cents(725800),
  });

  /// Months of spending that should sit in savings accounts.
  final int safetyBufferMonths;

  /// Target share of assets held in investments and Pillar 3a.
  final double longTermShare;

  /// Maximum Pillar 3a contribution for employees with a pension fund
  /// (CHF 7,258 in 2025 and 2026).
  final Money pillar3aAnnualLimit;

  WealthTargets copyWith({int? safetyBufferMonths, double? longTermShare}) =>
      WealthTargets(
        safetyBufferMonths: safetyBufferMonths ?? this.safetyBufferMonths,
        longTermShare: longTermShare ?? this.longTermShare,
        pillar3aAnnualLimit: pillar3aAnnualLimit,
      );

  Map<String, Object?> toJson() => {
    'safetyBufferMonths': safetyBufferMonths,
    'longTermShare': longTermShare,
  };

  static WealthTargets fromJson(Map<String, Object?> json) => WealthTargets(
    safetyBufferMonths: (json['safetyBufferMonths'] as num?)?.toInt() ?? 6,
    longTermShare: (json['longTermShare'] as num?)?.toDouble() ?? .45,
  );
}

enum AlertSeverity { info, warning, critical }

enum AlertKind { consentRequired, staleConnection, manualValueOutdated, billDue }

/// Something the user should know about, derived from their own data.
/// It carries facts only; the UI turns them into localized text.
class FinoraAlert {
  const FinoraAlert({
    required this.kind,
    required this.subject,
    this.bill,
    this.amount,
    this.daysUntilDue,
    this.route,
  });
  final AlertKind kind;

  /// Institution name or merchant the alert is about.
  final String subject;
  final BillCategory? bill;
  final Money? amount;
  final int? daysUntilDue;

  /// Optional in-app location that helps resolve the alert.
  final String? route;

  AlertSeverity get severity => switch (kind) {
    AlertKind.consentRequired => AlertSeverity.critical,
    AlertKind.staleConnection => AlertSeverity.warning,
    AlertKind.manualValueOutdated || AlertKind.billDue => AlertSeverity.info,
  };
}
