import 'package:finora/app/theme.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/data/importing_financial_repository.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/domain/category_rules.dart';
import 'package:finora/domain/imported_accounts.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/statement_import.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime(2026, 11, 4);

final _booking = FinancialTransaction(
  id: 't',
  accountId: 'a',
  merchant: 'Bäckerei  Müller',
  category: TransactionCategory.other,
  bookedAt: DateTime(2026, 11, 2),
  amount: const Money.cents(-850),
);

ImportedAccount _imported() => ImportedAccount.fromStatement(
  institutionId: 'ubs',
  name: 'Privatkonto',
  statement: StatementParser.parse(
    'Datum;Text;Betrag\n'
    '01.10.2026;Bäckerei Müller;-8.50\n'
    '02.10.2026;Bäckerei Müller;-6.20\n'
    '03.10.2026;Migros;-40.00\n',
  ),
  balance: const Money.cents(100000),
  importedAt: _now,
);

void main() {
  test('rules match merchants regardless of case and spaces', () {
    expect(CategoryRules.keyOf(' Bäckerei  MÜLLER '), 'bäckerei müller');
    final changed = CategoryRules.apply(_booking, {
      'bäckerei müller': TransactionCategory.groceries,
    });
    expect(changed.category, TransactionCategory.groceries);
    expect(changed.amount, _booking.amount);
    expect(identical(CategoryRules.apply(_booking, const {}), _booking), isTrue);
  });

  test('imported analytics follow the user\'s categories', () async {
    final repository = ImportingFinancialRepository(
      MockFinancialRepository(institutionIds: const {}, clock: () => _now),
      imported: [_imported()],
      categoryRules: const {'bäckerei müller': TransactionCategory.dining},
      clock: () => _now,
    );
    final transactions = await repository.getTransactions();
    expect(
      transactions
          .where((item) => item.merchant == 'Bäckerei Müller')
          .map((item) => item.category)
          .toSet(),
      {TransactionCategory.dining},
    );
    final account = (await repository.getAccounts()).single;
    final analytics = await repository.getAccountAnalytics(account.id);
    final dining = analytics.spendingCategories.firstWhere(
      (item) => item.category == TransactionCategory.dining,
    );
    expect(dining.amount, const Money.cents(1470));
  });

  test('demo bookings follow the rules too', () async {
    final base = MockFinancialRepository(
      institutionIds: InstitutionCatalogue.demoInstitutionIds,
      clock: () => _now,
    );
    final first = (await base.getTransactions()).first;
    final repository = ImportingFinancialRepository(
      base,
      imported: const [],
      categoryRules: {
        CategoryRules.keyOf(first.merchant): TransactionCategory.housing,
      },
      clock: () => _now,
    );
    final mapped = (await repository.getTransactions()).firstWhere(
      (item) => item.id == first.id,
    );
    expect(mapped.category, TransactionCategory.housing);
  });

  test('rules survive a round trip through storage', () {
    final session = UserSession.demo().copyWith(
      categoryRules: const {'migros': TransactionCategory.dining},
    );
    expect(
      UserSession.fromJson(session.toJson()).categoryRules,
      {'migros': TransactionCategory.dining},
    );
  });

  testWidgets('tapping a booking changes its category', (tester) async {
    usePhoneViewport(tester);
    final container = ProviderContainer(
      overrides: testOverrides(session: UserSession.demo()),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: TransactionTile(transaction: _booking)),
        ),
      ),
    );
    await tester.tap(find.text('Bäckerei  Müller'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Applies to every booking'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Groceries'));
    await tester.pumpAndSettle();
    expect(container.read(sessionProvider).categoryRules, {
      'bäckerei müller': TransactionCategory.groceries,
    });
    expect(tester.takeException(), isNull);
  });
}
