import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/debts.dart';
import 'package:finora/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debts in the plan: the user's list, or the connected credit cards until
/// the user has edited it.
final debtsProvider = FutureProvider<List<Debt>>((ref) async {
  final saved = ref.watch(sessionProvider.select((session) => session.debts));
  if (saved != null) return saved;
  final accounts = await ref.watch(accountsProvider.future);
  return [
    for (final account in accounts)
      if (account.type == FinancialProductType.creditCard &&
          account.balance.isNegative)
        Debt(
          id: 'account-${account.id}',
          name: account.name,
          kind: DebtKind.creditCard,
          balance: account.balance.abs(),
          yearlyRate: SwissCreditRules.maxCardRate,
          minimumPayment: SwissCreditRules.cardMinimum(account.balance.abs()),
        ),
  ];
});

/// Monthly payment for the plan: the user's choice, or the minimums plus
/// 10 %, rounded up to CHF 10.
final debtPaymentProvider = FutureProvider<Money>((ref) async {
  final chosen = ref.watch(
    sessionProvider.select((session) => session.debtPayment),
  );
  if (chosen != null) return chosen;
  final minimums = DebtPlanner.minimumTotal(await ref.watch(debtsProvider.future));
  final suggested = minimums * 1.1;
  return Money.cents(((suggested.cents + 999) ~/ 1000) * 1000);
});

/// Card payments abroad in the last 30 days.
final foreignSpendingProvider = FutureProvider<ForeignSpending>((ref) async {
  final transactions = await ref.watch(transactionsProvider(null).future);
  return ForeignSpending.of(transactions, ref.watch(clockProvider)());
});
