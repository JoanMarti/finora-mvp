import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/simulators.dart';
import 'package:finora/features/simulators/home_buying_screen.dart';
import 'package:finora/features/simulators/tax_savings_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Widget _screen(Widget child) => ProviderScope(
  overrides: testOverrides(),
  child: MaterialApp(
    theme: buildFinoraTheme(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

HomeAffordability _buyer({
  int income = 150000,
  int cash = 150000,
  int pillar3a = 50000,
  int pension = 0,
}) => HomeAffordability(
  grossYearlyIncome: Money(income.toDouble()),
  cashEquity: Money(cash.toDouble()),
  pillar3a: Money(pillar3a.toDouble()),
  pensionFundWithdrawal: Money(pension.toDouble()),
);

void main() {
  group('Home affordability', () {
    test('income limits a well-funded buyer', () {
      // 0.05 (P − 200k) + 0.01 P + (P/3 − 200k)/15 = 50k → P ≈ 891,900.
      final (price, limit) = _buyer().maxPrice;
      expect(limit, AffordabilityLimit.income);
      expect(price.amount, inInclusiveRange(889000, 892000));
      expect(price.cents % 100000, 0);
    });

    test('equity limits a high earner with little savings', () {
      final (price, limit) = _buyer(income: 400000, cash: 60000, pillar3a: 40000)
          .maxPrice;
      expect(limit, AffordabilityLimit.equity);
      expect(price, Money(500000));
    });

    test('pension fund money does not count as hard equity', () {
      final (price, limit) = _buyer(
        income: 400000,
        cash: 30000,
        pillar3a: 0,
        pension: 200000,
      ).maxPrice;
      // 10 % hard equity: 30k allows at most 300k.
      expect(limit, AffordabilityLimit.hardEquity);
      expect(price, Money(300000));
    });

    test('checks a price: cost, loan-to-value and needs', () {
      final buyer = _buyer();
      final check = buyer.check(Money(800000));
      expect(check.mortgage, Money(600000));
      expect(check.loanToValue, closeTo(.75, 1e-9));
      // 30k interest + 8k upkeep + (600k − 533,333)/15 amortisation.
      expect(check.yearlyCost.amount, closeTo(42444.44, 1));
      expect(buyer.fits(Money(800000)), isTrue);
      expect(buyer.fits(Money(1000000)), isFalse);
      expect(buyer.equityNeededFor(Money(800000)), Money(160000));
      expect(
        buyer.incomeNeededFor(Money(800000)).amount,
        closeTo(127333, 2),
      );
    });

    test('no income means no mortgage', () {
      final (price, _) = _buyer(income: 0).maxPrice;
      expect(price, Money.zero);
    });
  });

  group('Tax savings', () {
    test('deductions times the marginal rate', () {
      final result = TaxSavings.simulate(
        pillar3aContribution: Money(7258),
        buyIn: Money(20000),
        marginalRate: .3,
        yearsToRetirement: 20,
      );
      expect(result.deductions, Money(27258));
      expect(result.taxSaving.amount, closeTo(8177.4, .01));
      expect(result.netCost.amount, closeTo(19080.6, .01));
      // 20,000 × 1.0125^20 × 6.8 % / 12 ≈ CHF 145 a month.
      expect(result.extraMonthlyPension.amount, closeTo(145.4, 1));
    });

    test('without a buy-in there is no extra pension', () {
      final result = TaxSavings.simulate(
        pillar3aContribution: Money(3000),
        buyIn: Money.zero,
        marginalRate: .2,
        yearsToRetirement: 10,
      );
      expect(result.extraMonthlyPension, Money.zero);
      expect(result.taxSaving, Money(600));
    });
  });

  testWidgets('home buying starts from the user’s figures', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const HomeBuyingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Highest affordable price'), findsOneWidget);

    final price = find.widgetWithText(TextField, 'Purchase price');
    await tester.scrollUntilVisible(
      price,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(price, '3000000');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Share of gross income'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('This price is beyond the usual bank rules.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tax savings start with the 3a room left', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const TaxSavingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Estimated tax saving this year'), findsOneWidget);
    expect(find.textContaining('of room left this year'), findsOneWidget);

    final buyIn = find.widgetWithText(TextField, 'Buy-in amount');
    await tester.scrollUntilVisible(
      buyIn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(buyIn, '20000');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('Extra pension from the buy-in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
