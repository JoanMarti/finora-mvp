import 'package:finora/app/theme.dart';
import 'package:finora/domain/health_insurance.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/simulators/health_insurance_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('Deductible comparison', () {
    // CHF 400 a month with a CHF 300 deductible: CHF 4,800 a year.
    DeductibleComparison compare(int costs, {int current = 300}) =>
        DeductibleComparison.estimate(
          monthlyPremium: const Money.cents(40000),
          currentDeductible: current,
          expectedCosts: Money.cents(costs * 100),
        );

    test('premiums drop by 70 % of the extra risk', () {
      final options = compare(0).options;
      expect(options.first.yearlyPremium, const Money.cents(480000));
      // 2,500: 4,800 − 0.7 × 2,200 = 3,260.
      expect(options.last.yearlyPremium, const Money.cents(326000));
    });

    test('works from any current deductible', () {
      final from2500 = DeductibleComparison.estimate(
        monthlyPremium: Money.cents(326000 ~/ 12),
        currentDeductible: 2500,
        expectedCosts: Money.zero,
      );
      expect(
        from2500.options.first.yearlyPremium.cents,
        closeTo(480000, 100),
      );
    });

    test('costs: deductible, then 10 % up to CHF 700', () {
      final options = compare(10000).options;
      // CHF 10,000 with 300: 300 + 970 → capped at 700.
      expect(options.first.outOfPocket, const Money.cents(100000));
      // With 2,500: 2,500 + 700 (10 % of 7,500 = 750, capped).
      expect(options.last.outOfPocket, const Money.cents(320000));
      final small = compare(400).options;
      // CHF 400 with 300: 300 + 10 % of 100.
      expect(small.first.outOfPocket, const Money.cents(31000));
      expect(small.last.outOfPocket, const Money.cents(40000));
    });

    test('healthy years favour the highest deductible', () {
      final comparison = compare(200);
      expect(comparison.best.deductible, 2500);
      // 4,800 + 200 versus 3,260 + 200.
      expect(comparison.yearlySaving, const Money.cents(154000));
    });

    test('high costs favour the lowest deductible', () {
      final comparison = compare(8000, current: 2500);
      expect(comparison.best.deductible, 300);
      expect(comparison.yearlySaving.cents, greaterThan(0));
    });

    test('a bad year costs at most premium, deductible and CHF 700', () {
      final option = compare(0).options.last;
      expect(option.worstCase, const Money.cents(326000 + 250000 + 70000));
    });

    test('the change deadline is 30 November', () {
      expect(
        SwissHealthInsuranceRules.changeDeadline(DateTime(2026, 10, 28)),
        DateTime(2026, 11, 30),
      );
    });
  });

  testWidgets('the screen recommends a deductible', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(session: UserSession.demo()),
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HealthInsuranceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Best deductible for you'), findsOneWidget);
    // With the default CHF 500 of costs, the highest deductible wins.
    expect(find.textContaining('2,500').evaluate().isNotEmpty ||
        find.textContaining("2'500").evaluate().isNotEmpty, isTrue);
    expect(tester.takeException(), isNull);
  });
}
