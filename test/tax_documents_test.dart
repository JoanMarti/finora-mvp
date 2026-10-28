import 'package:finora/app/theme.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/profile.dart';
import 'package:finora/domain/tax_documents.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/tax_documents/tax_documents_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

FinancialAccount _account(String id, String bank, FinancialProductType type) =>
    FinancialAccount(
      id: id,
      institutionId: bank,
      name: id,
      type: type,
      balance: const Money.cents(100000),
      maskedIdentifier: '•••• 0001',
      monthlyChange: Money.zero,
    );

final _accounts = [
  _account('a', 'ubs', FinancialProductType.currentAccount),
  _account('b', 'ubs', FinancialProductType.savings),
  _account('c', 'zkb', FinancialProductType.currentAccount),
  _account('d', 'frankly', FinancialProductType.pillar3a),
  _account('e', 'ubs', FinancialProductType.creditCard),
];

void main() {
  group('Tax document checklist', () {
    test('lists one statement per bank and the usual papers', () {
      final checklist = TaxDocumentChecklist.build(
        now: DateTime(2026, 10, 28),
        accounts: _accounts,
        profile: const UserProfile(employment: Employment.employee),
      );
      expect(checklist.taxYear, 2026);
      expect(checklist.deadline, DateTime(2027, 3, 31));
      expect(checklist.documents.map((document) => document.id), [
        'salaryCertificate',
        'pensionCertificate',
        'bankStatement:ubs',
        'bankStatement:zkb',
        'pillar3aCertificate:frankly',
        'healthInsurance',
        'donations',
      ]);
    });

    test('until March it is last year\'s return', () {
      expect(TaxDocumentChecklist.taxYearFor(DateTime(2027, 3, 31)), 2026);
      expect(TaxDocumentChecklist.taxYearFor(DateTime(2027, 4, 1)), 2027);
    });

    test('follows the profile, property and loans', () {
      final checklist = TaxDocumentChecklist.build(
        now: DateTime(2026, 10, 28),
        accounts: [
          _account('m', 'raiffeisen', FinancialProductType.mortgage),
        ],
        profile: const UserProfile(
          employment: Employment.selfEmployed,
          children: 2,
        ),
        manualAssets: [
          ManualAsset(
            id: 'house',
            kind: ManualAssetKind.property,
            name: 'House',
            value: const Money.cents(90000000),
            valuedAt: DateTime(2026),
          ),
        ],
        hasLoans: true,
      );
      final kinds = checklist.documents.map((document) => document.kind);
      expect(kinds, contains(TaxDocumentKind.selfEmployedAccounts));
      expect(kinds, isNot(contains(TaxDocumentKind.salaryCertificate)));
      expect(kinds, isNot(contains(TaxDocumentKind.pensionCertificate)));
      expect(kinds, contains(TaxDocumentKind.mortgageInterest));
      expect(kinds, contains(TaxDocumentKind.propertyCosts));
      expect(kinds, contains(TaxDocumentKind.loanInterest));
      expect(kinds, contains(TaxDocumentKind.childcareCosts));
    });

    test('progress counts required papers of this tax year only', () {
      final checklist = TaxDocumentChecklist.build(
        now: DateTime(2026, 10, 28),
        accounts: _accounts,
        profile: const UserProfile(),
      );
      final ready = {
        '2026:salaryCertificate',
        '2026:donations',
        '2025:healthInsurance',
      };
      expect(checklist.readyCount(ready), 2);
      expect(checklist.progress(ready), closeTo(1 / 6, 1e-9));
    });

    test('ticked papers survive a round trip through storage', () {
      final session = UserSession.demo().copyWith(
        taxDocumentsReady: {'2026:salaryCertificate'},
      );
      expect(
        UserSession.fromJson(session.toJson()).taxDocumentsReady,
        {'2026:salaryCertificate'},
      );
    });
  });

  testWidgets('ticking a paper updates the progress', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(session: UserSession.demo()),
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const TaxDocumentsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Papers for your 2026 tax return'), findsOneWidget);
    expect(find.textContaining('0 of '), findsOneWidget);
    final health = find.text('Health insurance premium statement');
    await tester.scrollUntilVisible(
      health,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(health);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining(' of '),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
