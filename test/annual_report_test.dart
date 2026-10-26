import 'dart:typed_data';

import 'package:finora/app/theme.dart';
import 'package:finora/application/annual_report.dart';
import 'package:finora/domain/annual_report.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/report/annual_report_pdf.dart';
import 'package:finora/features/report/annual_report_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'test_helpers.dart';

final _now = DateTime(2026, 10, 15);

List<CashFlowPoint> _months(int count) => [
  for (var index = count; index >= 0; index--)
    CashFlowPoint(
      month: DateTime(2026, 10 - index),
      income: const Money.cents(700000),
      // October 2025 is the toughest month, August 2026 the best one.
      spending: Money.cents(
        index == 12
            ? 750000
            : index == 2
            ? 400000
            : 600000,
      ),
    ),
];

RecurringPayment _bill(String merchant, int cents) => RecurringPayment(
  merchant: merchant,
  category: BillCategory.values.first,
  amount: Money.cents(-cents),
  cadence: BillCadence.monthly,
  nextDueAt: _now,
);

AnnualReport _report() => AnnualReport.of(
  cashFlow: _months(14),
  netWorth: [
    BalanceHistoryPoint(
      month: DateTime(2025, 9),
      balance: const Money.cents(10000000),
    ),
    BalanceHistoryPoint(
      month: DateTime(2026, 9),
      balance: const Money.cents(11500000),
    ),
  ],
  recurring: [
    for (final (name, cents) in [
      ('Helsana', 41200),
      ('Swisscom', 8990),
      ('Rent', 210000),
      ('Netflix', 2290),
      ('Spotify', 1295),
      ('SBB', 34000),
    ])
      _bill(name, cents),
    _bill('Swisscom', 8490),
  ],
  priceChanges: const [],
  now: _now,
)!;

class _FakeSharer implements PdfSharer {
  final shared = <(Uint8List, String)>[];

  @override
  Future<void> share(Uint8List bytes, String filename) async {
    shared.add((bytes, filename));
  }
}

void main() {
  group('Annual report', () {
    test('covers the last twelve completed months', () {
      final report = _report();
      expect(report.months, hasLength(12));
      expect(report.start, DateTime(2025, 10));
      expect(report.end, DateTime(2026, 9));
      expect(report.income, const Money.cents(8400000));
      expect(report.spending, const Money.cents(7150000));
      expect(report.saved, const Money.cents(1250000));
    });

    test('finds the best and the toughest month', () {
      final report = _report();
      expect(report.bestMonth.month, DateTime(2026, 8));
      expect(report.toughestMonth.month, DateTime(2025, 10));
    });

    test('net worth runs from the month before the first one', () {
      expect(_report().netWorthChange, const Money.cents(1500000));
    });

    test('lists each bill once, the most expensive first', () {
      final report = _report();
      expect(report.topBills.map((bill) => bill.merchant), [
        'Rent',
        'Helsana',
        'SBB',
        'Swisscom',
        'Netflix',
      ]);
      expect(report.topBills[3].yearly, const Money.cents(8990 * 12));
    });

    test('needs three completed months', () {
      expect(
        AnnualReport.of(
          cashFlow: _months(2),
          netWorth: const [],
          recurring: const [],
          priceChanges: const [],
          now: _now,
        ),
        isNull,
      );
    });

    test('builds a PDF in every language', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final code in ['en', 'de', 'fr', 'it']) {
        await initializeDateFormatting(code);
        final bytes = await buildAnnualReportPdf(
          _report(),
          lookupAppLocalizations(Locale(code)),
          createdAt: _now,
          firstName: 'Anna',
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      }
      expect(annualReportFileName(_report()), 'finora-annual-report-2026-09.pdf');
    });
  });

  Widget app(UserSession session, _FakeSharer sharer) => ProviderScope(
    overrides: [
      ...testOverrides(session: session),
      pdfSharerProvider.overrideWithValue(sharer),
    ],
    child: MaterialApp(
      theme: buildFinoraTheme(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const AnnualReportScreen(),
    ),
  );

  testWidgets('free users see what the annual report holds', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(app(UserSession.demo(), _FakeSharer()));
    await tester.pumpAndSettle();
    expect(find.text('Your year in one PDF'), findsOneWidget);
    expect(find.text('Download PDF'), findsNothing);
  });

  testWidgets('Premium downloads the year as a PDF', (tester) async {
    usePhoneViewport(tester);
    final sharer = _FakeSharer();
    await tester.pumpWidget(
      app(UserSession.demo().copyWith(plan: FinoraPlan.plus), sharer),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Your year in Finora'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Download PDF'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download PDF'));
    await tester.runAsync(() async {
      for (var tries = 0; tries < 100 && sharer.shared.isEmpty; tries++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
    expect(sharer.shared, hasLength(1));
    expect(String.fromCharCodes(sharer.shared.single.$1.take(5)), '%PDF-');
    expect(sharer.shared.single.$2, startsWith('finora-annual-report-'));
    expect(tester.takeException(), isNull);
  });
}
