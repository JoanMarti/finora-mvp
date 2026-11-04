import 'package:finora/domain/models.dart';

/// The categories the user chose, by merchant.
abstract final class CategoryRules {
  /// Rules are kept by merchant name, ignoring case and extra spaces.
  static String keyOf(String merchant) =>
      merchant.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// [transaction] with the user's category for its merchant, if any.
  static FinancialTransaction apply(
    FinancialTransaction transaction,
    Map<String, TransactionCategory> rules,
  ) {
    final category = rules[keyOf(transaction.merchant)];
    if (category == null || category == transaction.category) {
      return transaction;
    }
    return FinancialTransaction(
      id: transaction.id,
      accountId: transaction.accountId,
      merchant: transaction.merchant,
      category: category,
      bookedAt: transaction.bookedAt,
      amount: transaction.amount,
      foreignCurrency: transaction.foreignCurrency,
    );
  }

  static List<FinancialTransaction> applyAll(
    List<FinancialTransaction> transactions,
    Map<String, TransactionCategory> rules,
  ) => rules.isEmpty
      ? transactions
      : [for (final item in transactions) apply(item, rules)];
}
