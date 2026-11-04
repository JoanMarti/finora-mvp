import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/transaction_filter.dart';
import 'package:finora/features/activity/activity_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime(2026, 11, 4);

FinancialTransaction _item(
  String id,
  DateTime date,
  int cents, {
  TransactionCategory category = TransactionCategory.groceries,
  String account = 'a',
}) => FinancialTransaction(
  id: id,
  accountId: account,
  merchant: id,
  category: category,
  bookedAt: date,
  amount: Money.cents(cents),
);

final _items = [
  _item('today', DateTime(2026, 11, 2), -1000),
  _item('salary', DateTime(2026, 10, 25), 500000,
      category: TransactionCategory.income),
  _item('august', DateTime(2026, 8, 31), -2000, account: 'b'),
  _item('old', DateTime(2025, 6, 1), -3000,
      category: TransactionCategory.transport),
];

List<String> _ids(TransactionFilter filter) => [
  for (final item in _items)
    if (filter.matches(item, _now)) item.id,
];

void main() {
  test('periods count whole months back from this one', () {
    expect(
      _ids(const TransactionFilter(period: ActivityPeriod.thisMonth)),
      ['today'],
    );
    expect(
      _ids(const TransactionFilter(period: ActivityPeriod.threeMonths)),
      ['today', 'salary'],
    );
    expect(
      _ids(const TransactionFilter(period: ActivityPeriod.twelveMonths)),
      ['today', 'salary', 'august'],
    );
    expect(_ids(const TransactionFilter()), hasLength(4));
  });

  test('direction, categories and account', () {
    expect(
      _ids(const TransactionFilter(direction: ActivityDirection.moneyIn)),
      ['salary'],
    );
    expect(
      _ids(const TransactionFilter(direction: ActivityDirection.moneyOut)),
      ['today', 'august', 'old'],
    );
    expect(
      _ids(
        const TransactionFilter(categories: {TransactionCategory.transport}),
      ),
      ['old'],
    );
    expect(_ids(const TransactionFilter(accountId: 'b')), ['august']);
  });

  test('active filters are counted and can be cleared', () {
    const filter = TransactionFilter(
      period: ActivityPeriod.thisMonth,
      categories: {TransactionCategory.dining},
    );
    expect(filter.activeCount, 2);
    expect(filter.copyWith(accountId: () => 'a').activeCount, 3);
    expect(
      filter.copyWith(accountId: () => 'a').copyWith(accountId: () => null)
          .activeCount,
      2,
    );
    expect(const TransactionFilter().isEmpty, isTrue);
  });

  test('totals of money in and out', () {
    final totals = ActivityTotals.of(_items);
    expect(totals.moneyIn, const Money.cents(500000));
    expect(totals.moneyOut, const Money.cents(6000));
  });

  testWidgets('the filter sheet narrows the list', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(),
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ActivityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Migros'), findsOneWidget);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money in'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'^Show \d+ bookings$')));
    await tester.pumpAndSettle();
    expect(find.text('Filters (1)'), findsOneWidget);
    expect(find.text('Migros'), findsNothing);
    expect(find.textContaining(RegExp(r'out CHF.0$')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
