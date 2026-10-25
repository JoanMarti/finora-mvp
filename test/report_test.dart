import 'package:finora/app/theme.dart';
import 'package:finora/application/report.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/report.dart';
import 'package:finora/features/report/report_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

CashFlowPoint _flow(int month, int income, int spending) => CashFlowPoint(
  month: DateTime(2026, month),
  income: Money(income.toDouble()),
  spending: Money(spending.toDouble()),
);

final _cashFlow = [
  _flow(6, 9000, 7000),
  _flow(7, 9000, 6500),
  _flow(8, 9000, 8000),
  _flow(9, 9500, 6000),
  _flow(10, 9000, 3000), // running month
];

final _netWorth = [
  BalanceHistoryPoint(month: DateTime(2026, 8), balance: Money(100000)),
  BalanceHistoryPoint(month: DateTime(2026, 9), balance: Money(103000)),
];

void main() {
  group('Monthly report', () {
    test('compares a month with the one before and the average', () {
      final report = MonthlyReport.of(
        month: DateTime(2026, 9),
        cashFlow: _cashFlow,
        netWorth: _netWorth,
        subscriptionsSaved: Money(298.8),
      )!;
      expect(report.saved, Money(3500));
      expect(report.savingsRate, closeTo(3500 / 9500, 1e-9));
      expect(report.previousSavingsRate, closeTo(1000 / 9000, 1e-9));
      expect(report.spendingChange, closeTo(-.25, 1e-9));
      expect(report.averageSpending, Money(6875));
      expect(report.netWorthChange, Money(3000));
      expect(report.highlights.map((h) => h.kind), [
        ReportHighlightKind.bestSavingsMonth,
        ReportHighlightKind.spendingBelowAverage,
        ReportHighlightKind.netWorthUp,
        ReportHighlightKind.subscriptionsSaved,
      ]);
      final below = report.highlights[1];
      expect(below.amount, Money(875));
      expect(below.percent, 13);
    });

    test('only completed months, most recent first', () {
      expect(MonthlyReport.availableMonths(_cashFlow, testNow), [
        DateTime(2026, 9),
        DateTime(2026, 8),
        DateTime(2026, 7),
        DateTime(2026, 6),
      ]);
      expect(
        MonthlyReport.of(
          month: DateTime(2026, 1),
          cashFlow: _cashFlow,
          netWorth: _netWorth,
        ),
        isNull,
      );
    });

    test('a short history has no average-based highlights', () {
      final report = MonthlyReport.of(
        month: DateTime(2026, 7),
        cashFlow: _cashFlow,
        netWorth: const [],
      )!;
      expect(report.highlights, isEmpty);
      expect(report.netWorthChange, isNull);
    });

    test('the demo profile reports on September', () async {
      final container = createTestContainer();
      final months = await container.read(reportMonthsProvider.future);
      expect(months.first, DateTime(2026, 9));
      final report = await container.read(
        monthlyReportProvider(months.first).future,
      );
      expect(report, isNotNull);
      expect(report!.income.cents, greaterThan(0));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.reportSummary(report), contains('Income CHF'));
    });
  });

  testWidgets('the report screen shows last month and copies it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(),
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ReportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your September 2026'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy summary'));
    await tester.pumpAndSettle();
    expect(copied, startsWith('Your September 2026'));
    expect(find.text('Summary copied.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
