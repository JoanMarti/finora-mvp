enum FinancialProductType {
  currentAccount('Current account'),
  savings('Savings'),
  investments('Investments'),
  pillar3a('Pillar 3a'),
  creditCard('Credit card'),
  mortgage('Mortgage');

  const FinancialProductType(this.label);
  final String label;
}

enum ConnectionStatus { connected, stale, actionRequired, manual }

class Money {
  const Money(this.amount, {this.currency = 'CHF'});
  final double amount;
  final String currency;
}

class Institution {
  const Institution({
    required this.id,
    required this.name,
    required this.shortName,
    required this.colorValue,
  });
  final String id;
  final String name;
  final String shortName;
  final int colorValue;
}

class InstitutionConnection {
  const InstitutionConnection({
    required this.institutionId,
    required this.status,
    required this.lastSyncLabel,
  });
  final String institutionId;
  final ConnectionStatus status;
  final String lastSyncLabel;
}

class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.type,
    required this.balance,
    required this.maskedIdentifier,
    required this.change,
  });
  final String id;
  final String institutionId;
  final String name;
  final FinancialProductType type;
  final Money balance;
  final String maskedIdentifier;
  final double change;
}

class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.accountId,
    required this.merchant,
    required this.category,
    required this.dateLabel,
    required this.amount,
  });
  final String id;
  final String accountId;
  final String merchant;
  final String category;
  final String dateLabel;
  final Money amount;
}

class FinancialOverview {
  const FinancialOverview({
    required this.total,
    required this.cash,
    required this.investments,
    required this.retirement,
    required this.monthlyChange,
  });
  final Money total;
  final Money cash;
  final Money investments;
  final Money retirement;
  final double monthlyChange;
}

class BalanceHistoryPoint {
  const BalanceHistoryPoint({required this.label, required this.balance});
  final String label;
  final double balance;
}

class CashFlowPoint {
  const CashFlowPoint({
    required this.label,
    required this.income,
    required this.spending,
  });
  final String label;
  final double income;
  final double spending;
}

class RecurringPayment {
  const RecurringPayment({
    required this.merchant,
    required this.category,
    required this.amount,
    required this.cadence,
    required this.nextDueLabel,
  });
  final String merchant;
  final String category;
  final Money amount;
  final String cadence;
  final String nextDueLabel;
}

class SpendingCategory {
  const SpendingCategory({
    required this.label,
    required this.amount,
    required this.colorValue,
  });
  final String label;
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
  final Money monthlyIncome;
  final Money monthlySpending;
  final List<BalanceHistoryPoint> balanceHistory;
  final List<CashFlowPoint> cashFlowHistory;
  final List<RecurringPayment> recurringPayments;
  final List<SpendingCategory> spendingCategories;

  double get monthlyNet => monthlyIncome.amount - monthlySpending.amount;
  double get savingsRate =>
      monthlyIncome.amount == 0 ? 0 : monthlyNet / monthlyIncome.amount;
  double get recurringTotal => recurringPayments.fold(
    0,
    (total, payment) => total + payment.amount.amount.abs(),
  );
}
