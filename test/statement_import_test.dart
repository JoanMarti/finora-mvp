import 'dart:convert';
import 'dart:typed_data';

import 'package:finora/app/theme.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/application/statement_import.dart';
import 'package:finora/data/importing_financial_repository.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/domain/imported_accounts.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/merchant_categories.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/statement_import.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/import/import_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime(2026, 11, 3);

/// Shaped like a German-language e-banking export: account details first,
/// then the bookings, newest first, with a balance column.
const _germanCsv = '''
Kontonummer:;0235 00123456.01;
IBAN:;CH93 0023 5235 1234 5601 0;
Bewertet in:;CHF;

Abschlussdatum;Buchungsdatum;Valuta;Beschreibung1;Beschreibung2;Belastung;Gutschrift;Saldo
31.10.2026;31.10.2026;31.10.2026;"Migros Zürich";"Kartenzahlung";-84.35;;12'480.40
25.10.2026;25.10.2026;25.10.2026;"Lohn Oktober";"Muster AG";;6'850.00;12'564.75
05.10.2026;05.10.2026;05.10.2026;"CSS Versicherung";"Prämie";348.20;;5'714.75
05.09.2026;05.09.2026;05.09.2026;"CSS Versicherung";"Prämie";348.20;;6'062.95
05.08.2026;05.08.2026;05.08.2026;"CSS Versicherung";"Prämie";348.20;;6'411.15
''';

const _englishCsv = '''
Date,Description,Amount,Currency
2026-10-02,"Coop Pronto, Bern",-12.50,CHF
2026-10-03,Salt Mobile SA,-39.95,CHF
2026-10-04,"Refund ""Galaxus""","1,234.50",CHF
''';

ParsedStatement _parse(String text) => StatementParser.parse(text);

ImportedAccount _account(String csv, {int balanceCents = 1248040}) =>
    ImportedAccount.fromStatement(
      institutionId: 'ubs',
      name: 'Privatkonto',
      statement: _parse(csv),
      balance: Money.cents(balanceCents),
      importedAt: _now,
    );

class _FakePicker implements StatementFilePicker {
  _FakePicker(this.text);
  final String text;

  @override
  Future<String?> pick() async => text;
}

void main() {
  group('Statement parser', () {
    test('reads a German export with debit and credit columns', () {
      final statement = _parse(_germanCsv);
      expect(statement.rows, hasLength(5));
      expect(statement.firstDate, DateTime(2026, 8, 5));
      expect(statement.lastDate, DateTime(2026, 10, 31));
      expect(statement.rows.last.amount, const Money.cents(-8435));
      expect(statement.rows.last.text, 'Migros Zürich Kartenzahlung');
      expect(statement.rows[3].amount, const Money.cents(685000));
      expect(statement.rows.first.amount, const Money.cents(-34820));
      expect(statement.closingBalance, const Money.cents(1248040));
      expect(statement.income, const Money.cents(685000));
    });

    test('reads an English export with quotes and one amount column', () {
      final statement = _parse(_englishCsv);
      expect(statement.rows.map((row) => row.amount.cents), [
        -1250,
        -3995,
        123450,
      ]);
      expect(statement.rows.first.text, 'Coop Pronto, Bern');
      expect(statement.rows.last.text, 'Refund "Galaxus"');
      expect(statement.closingBalance, isNull);
    });

    test('amounts in Swiss and European formats', () {
      expect(StatementParser.parseCents("1'234.50"), 123450);
      expect(StatementParser.parseCents('-1234,5'), -123450);
      expect(StatementParser.parseCents('1.234,56'), 123456);
      expect(StatementParser.parseCents('12.50-'), -1250);
      expect(StatementParser.parseCents('CHF 8.90'), 890);
      expect(StatementParser.parseCents('1,234'), 123400);
      expect(StatementParser.parseCents(''), isNull);
      expect(StatementParser.parseCents('n/a'), isNull);
    });

    test('dates in the usual formats', () {
      expect(StatementParser.parseDate('31.10.2026'), DateTime(2026, 10, 31));
      expect(StatementParser.parseDate('31.10.26'), DateTime(2026, 10, 31));
      expect(StatementParser.parseDate('2026-10-31'), DateTime(2026, 10, 31));
      expect(
        StatementParser.parseDate('2026-10-31 00:00:00'),
        DateTime(2026, 10, 31),
      );
      expect(StatementParser.parseDate('31/10/2026'), DateTime(2026, 10, 31));
      expect(StatementParser.parseDate('31.02.2026'), isNull);
      expect(StatementParser.parseDate('Total'), isNull);
    });

    test('explains files it cannot read', () {
      Matcher problem(StatementProblem value) => throwsA(
        isA<StatementFormatException>().having(
          (error) => error.problem,
          'problem',
          value,
        ),
      );
      expect(() => _parse('   \n'), problem(StatementProblem.empty));
      expect(() => _parse('a;b;c\n1;2;3'), problem(StatementProblem.noHeader));
      expect(
        () => _parse('Datum;Text\n01.10.2026;Migros'),
        problem(StatementProblem.noAmount),
      );
      expect(
        () => _parse('Datum;Betrag\nTotal;12.00'),
        problem(StatementProblem.noRows),
      );
    });

    test('Latin-1 files are decoded', () {
      final bytes = Uint8List.fromList(latin1.encode('Datum;Betrag\nZürich'));
      expect(decodeStatement(bytes), contains('Zürich'));
      expect(
        decodeStatement(Uint8List.fromList(utf8.encode('Zürich'))),
        'Zürich',
      );
    });
  });

  group('Merchant categories', () {
    test('well-known merchants', () {
      const out = Money.cents(-100);
      expect(
        MerchantCategories.categorize('MIGROS M BERN', out),
        TransactionCategory.groceries,
      );
      expect(
        MerchantCategories.categorize('SBB CFF FFS', out),
        TransactionCategory.transport,
      );
      expect(
        MerchantCategories.categorize('CSS Versicherung', out),
        TransactionCategory.insurance,
      );
      expect(
        MerchantCategories.categorize('Salt Mobile SA', out),
        TransactionCategory.utilities,
      );
      expect(
        MerchantCategories.categorize('Unknown shop', out),
        TransactionCategory.other,
      );
      expect(
        MerchantCategories.categorize('Lohn', const Money.cents(100)),
        TransactionCategory.income,
      );
      // "css" inside another word is not the insurer.
      expect(
        MerchantCategories.billCategory('Access Fitness'),
        BillCategory.membership,
      );
      expect(
        MerchantCategories.billCategory('CSS Versicherung'),
        BillCategory.healthInsurance,
      );
      expect(MerchantCategories.billCategory('Netflix'), BillCategory.streaming);
      expect(MerchantCategories.billCategory('Miete Oktober'), isNull);
    });

    test('merchant names drop card numbers and prefixes', () {
      expect(
        MerchantCategories.merchantName('Kartenzahlung: Migros Bern 1234XXXX5678'),
        'Migros Bern',
      );
    });
  });

  group('Imported account', () {
    test('balance on a past day rolls back the bookings since', () {
      final account = _account(_germanCsv);
      expect(account.balanceOn(_now), const Money.cents(1248040));
      expect(
        account.balanceOn(DateTime(2026, 10, 24)),
        const Money.cents(1248040 + 8435 - 685000),
      );
    });

    test('a second import adds only new bookings', () {
      final first = _account(_germanCsv);
      final again = _account(_germanCsv).merge(first);
      expect(again.transactions, hasLength(5));
      final more = first.merge(
        ImportedAccount.fromStatement(
          institutionId: 'ubs',
          name: 'Privatkonto',
          statement: _parse('Datum;Text;Betrag\n02.11.2026;Coop;-20.00'),
          balance: const Money.cents(1246040),
          importedAt: _now,
        ),
      );
      expect(more.transactions, hasLength(6));
      expect(more.balance, const Money.cents(1246040));
    });

    test('survives a round trip through storage', () {
      final account = _account(_germanCsv);
      final session = UserSession.demo().copyWith(importedAccounts: [account]);
      final restored = UserSession.fromJson(session.toJson()).importedAccounts;
      expect(restored.single.id, account.id);
      expect(restored.single.transactions, hasLength(5));
      expect(
        restored.single.transactions.last.category,
        TransactionCategory.groceries,
      );
    });

    test('analytics: cash flow per month and the recurring premium', () {
      final analytics = ImportedAnalytics.build(_account(_germanCsv), now: _now);
      expect(analytics.cashFlowHistory.map((point) => point.month), [
        DateTime(2026, 8),
        DateTime(2026, 9),
        DateTime(2026, 10),
        DateTime(2026, 11),
      ]);
      expect(
        analytics.cashFlowHistory[2].income,
        const Money.cents(685000),
      );
      final bill = analytics.recurringPayments.single;
      expect(bill.category, BillCategory.healthInsurance);
      expect(bill.amount, const Money.cents(-34820));
      expect(bill.nextDueAt, DateTime(2026, 11, 5));
      expect(analytics.balanceHistory.last.balance, const Money.cents(1248040));
    });
  });

  test('an import replaces the demo current account of that bank', () async {
    final repository = ImportingFinancialRepository(
      MockFinancialRepository(
        institutionIds: InstitutionCatalogue.demoInstitutionIds,
        clock: () => _now,
      ),
      imported: [_account(_germanCsv)],
      clock: () => _now,
    );
    final accounts = await repository.getAccounts();
    final ubsCurrent = accounts.where(
      (account) =>
          account.institutionId == 'ubs' &&
          account.type == FinancialProductType.currentAccount,
    );
    expect(ubsCurrent.single.name, 'Privatkonto');
    final transactions = await repository.getTransactions();
    expect(
      transactions.where((item) => item.merchant.contains('Migros Zürich')),
      isNotEmpty,
    );

    final elsewhere = ImportingFinancialRepository(
      MockFinancialRepository(institutionIds: const {}, clock: () => _now),
      imported: [_account(_germanCsv)],
      clock: () => _now,
    );
    expect(
      (await elsewhere.getInstitutions()).map((item) => item.id),
      ['ubs'],
    );
    expect(
      (await elsewhere.getConnections()).single.status,
      ConnectionStatus.manual,
    );
  });

  testWidgets('a chosen file is previewed and imported', (tester) async {
    usePhoneViewport(tester);
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(session: UserSession.demo()),
        statementFilePickerProvider.overrideWithValue(_FakePicker(_germanCsv)),
      ],
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
          home: const ImportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose CSV file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 bookings from'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Import');
    await tester.scrollUntilVisible(
      confirm,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    final imported = container.read(sessionProvider).importedAccounts;
    expect(imported.single.transactions, hasLength(5));
    expect(imported.single.balance, const Money.cents(1248040));
    expect(tester.takeException(), isNull);
  });
}
