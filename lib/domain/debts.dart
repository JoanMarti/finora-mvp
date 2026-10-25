import 'package:finora/domain/models.dart';

/// Swiss consumer credit limits (Consumer Credit Act): since July 2016 the
/// maximum annual rate is 10 % for cash loans and 12 % for overdrafts and
/// credit card balances.
abstract final class SwissCreditRules {
  static const maxCashLoanRate = .10;
  static const maxCardRate = .12;

  /// Typical minimum card payment: 5 % of the balance, at least CHF 50.
  static Money cardMinimum(Money balance) {
    final fivePercent = balance * .05;
    const floor = Money.cents(5000);
    if (balance.cents < floor.cents) return balance;
    return fivePercent.cents > floor.cents ? fivePercent : floor;
  }
}

enum DebtKind { creditCard, loan, leasing, other }

class Debt {
  const Debt({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.yearlyRate,
    required this.minimumPayment,
  });

  final String id;
  final String name;
  final DebtKind kind;

  /// Outstanding amount, positive.
  final Money balance;
  final double yearlyRate;
  final Money minimumPayment;

  /// Above the legal maximum for its kind (worth checking with the lender).
  bool get aboveLegalRate => switch (kind) {
    DebtKind.creditCard => yearlyRate > SwissCreditRules.maxCardRate + 1e-9,
    DebtKind.loan => yearlyRate > SwissCreditRules.maxCashLoanRate + 1e-9,
    DebtKind.leasing || DebtKind.other => false,
  };

  Debt copyWith({
    String? name,
    DebtKind? kind,
    Money? balance,
    double? yearlyRate,
    Money? minimumPayment,
  }) => Debt(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    balance: balance ?? this.balance,
    yearlyRate: yearlyRate ?? this.yearlyRate,
    minimumPayment: minimumPayment ?? this.minimumPayment,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'balance': balance.cents,
    'yearlyRate': yearlyRate,
    'minimumPayment': minimumPayment.cents,
  };

  static Debt? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = DebtKind.values
        .where((value) => value.name == raw['kind'])
        .firstOrNull;
    final balance = raw['balance'];
    final minimum = raw['minimumPayment'];
    final rate = raw['yearlyRate'];
    if (kind == null ||
        raw['id'] is! String ||
        balance is! int ||
        minimum is! int ||
        rate is! num) {
      return null;
    }
    return Debt(
      id: raw['id'] as String,
      name: raw['name'] as String? ?? '',
      kind: kind,
      balance: Money.cents(balance),
      yearlyRate: rate.toDouble(),
      minimumPayment: Money.cents(minimum),
    );
  }
}

/// Avalanche pays the highest rate first (least interest); snowball pays
/// the smallest balance first (quick wins).
enum PayoffStrategy { avalanche, snowball }

class DebtPayoff {
  const DebtPayoff({
    required this.months,
    required this.totalInterest,
    required this.payoffMonths,
    required this.monthlyPayment,
    required this.feasible,
  });

  /// Months until everything is repaid.
  final int months;
  final Money totalInterest;

  /// Debt id → the month (1-based) it is repaid in, in payoff order.
  final Map<String, int> payoffMonths;

  /// Payment actually used: never below the sum of the minimums.
  final Money monthlyPayment;

  /// `false` when the payment does not even cover the interest.
  final bool feasible;
}

abstract final class DebtPlanner {
  static const maxMonths = 600;

  static Money minimumTotal(List<Debt> debts) =>
      Money.sum(debts.map((debt) => debt.minimumPayment));

  static DebtPayoff simulate(
    List<Debt> debts,
    Money monthlyBudget,
    PayoffStrategy strategy,
  ) {
    final balances = {
      for (final debt in debts)
        if (debt.balance.cents > 0) debt.id: debt.balance.cents.toDouble(),
    };
    final minimums = minimumTotal(debts);
    final payment = monthlyBudget.cents < minimums.cents
        ? minimums
        : monthlyBudget;
    final order = [...debts]
      ..sort(
        (a, b) => switch (strategy) {
          PayoffStrategy.avalanche => b.yearlyRate.compareTo(a.yearlyRate),
          PayoffStrategy.snowball => a.balance.compareTo(b.balance),
        },
      );
    final payoff = <String, int>{};
    var interest = 0.0;
    var month = 0;
    while (balances.values.any((balance) => balance > .5) &&
        month < maxMonths) {
      month++;
      var available = payment.cents.toDouble();
      for (final debt in debts) {
        final balance = balances[debt.id];
        if (balance == null || balance <= .5) continue;
        final charge = balance * debt.yearlyRate / 12;
        interest += charge;
        balances[debt.id] = balance + charge;
      }
      // Minimums first, then everything left to the target debt.
      for (final debt in debts) {
        final balance = balances[debt.id];
        if (balance == null || balance <= .5) continue;
        final pay = [
          debt.minimumPayment.cents.toDouble(),
          balance,
          available,
        ].reduce((a, b) => a < b ? a : b);
        balances[debt.id] = balance - pay;
        available -= pay;
      }
      for (final debt in order) {
        if (available <= 0) break;
        final balance = balances[debt.id];
        if (balance == null || balance <= .5) continue;
        final pay = balance < available ? balance : available;
        balances[debt.id] = balance - pay;
        available -= pay;
      }
      for (final debt in order) {
        final balance = balances[debt.id];
        if (balance != null && balance <= .5 && !payoff.containsKey(debt.id)) {
          payoff[debt.id] = month;
        }
      }
    }
    final feasible = !balances.values.any((balance) => balance > .5);
    return DebtPayoff(
      months: month,
      totalInterest: Money.cents(interest.round()),
      payoffMonths: payoff,
      monthlyPayment: payment,
      feasible: feasible,
    );
  }
}

// -----------------------------------------------------------------------------
// Spending abroad
// -----------------------------------------------------------------------------

/// Card payments in other currencies and what the card's currency fees
/// probably cost.
class ForeignSpending {
  const ForeignSpending({
    required this.lastMonth,
    required this.currencies,
    required this.count,
  });

  factory ForeignSpending.of(
    List<FinancialTransaction> transactions,
    DateTime now,
  ) {
    final since = now.subtract(const Duration(days: window));
    final foreign = [
      for (final item in transactions)
        if (item.isForeign &&
            item.amount.isNegative &&
            !item.bookedAt.isBefore(since))
          item,
    ];
    return ForeignSpending(
      lastMonth: Money.sum(foreign.map((item) => item.amount.abs())),
      currencies: {for (final item in foreign) item.foreignCurrency!},
      count: foreign.length,
    );
  }

  static const window = 30;

  /// Typical Swiss card fee on payments in other currencies (processing
  /// fee plus exchange margin) against a card without such fees.
  static const typicalFee = .0175;
  static const feeFreeCost = .0025;

  final Money lastMonth;
  final Set<String> currencies;
  final int count;

  bool get isEmpty => count == 0;

  /// The last 30 days projected over a year; travel is irregular, so this
  /// is only a rough estimate.
  Money get yearlyEstimate => lastMonth * 12;
  Money get yearlyFees => yearlyEstimate * typicalFee;
  Money get yearlySaving => yearlyEstimate * (typicalFee - feeFreeCost);
}
