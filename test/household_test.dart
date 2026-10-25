import 'package:finora/app/theme.dart';
import 'package:finora/application/household.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/household.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/household/household_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Widget _screen(Widget child, {UserSession? session}) => ProviderScope(
  overrides: testOverrides(session: session),
  child: MaterialApp(
    theme: buildFinoraTheme(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

RetirementProjection _projection(int ahvFrancs) => RetirementProjection(
  retirementYear: 2053,
  yearsToRetirement: 27,
  ahvMonthly: Money.cents(ahvFrancs * 100),
  pensionFundCapital: Money(500000),
  pensionFundMonthly: Money(2000),
  pillar3aCapital: Money(200000),
  pillar3aMonthly: Money(800),
  targetMonthly: Money(6000),
);

const _anna = Household(
  partnerName: 'Anna',
  relationship: Relationship.married,
  partnerMonthlyIncome: Money.cents(465000),
  partnerCash: Money.cents(2500000),
  partnerInvestments: Money.cents(1000000),
  partnerPillar3a: Money.cents(3000000),
  partnerDebts: Money.cents(500000),
);

final _plus = UserSession.demo().copyWith(plan: FinoraPlan.plus);

void main() {
  group('Couple retirement', () {
    test('married couples share the 150 % AHV cap', () {
      // Two maximum pensions incl. the 13th: 2 × 2,730 = 5,460 a month.
      final couple = CoupleRetirement.of(
        _projection(2730),
        _projection(2730),
        relationship: Relationship.married,
      );
      expect(couple.isCapped, isTrue);
      // 150 % of 2,520 × 13/12 = 4,095.
      expect(couple.ahv, Money(4095));
      expect(couple.capReduction, Money(1365));
      expect(couple.totalMonthly, Money(4095 + 4000 + 1600));
      expect(couple.targetMonthly, Money(12000));
    });

    test('cohabiting partners keep two full pensions', () {
      final couple = CoupleRetirement.of(
        _projection(2730),
        _projection(2730),
        relationship: Relationship.cohabiting,
      );
      expect(couple.isCapped, isFalse);
      expect(couple.ahv, Money(5460));
    });

    test('below the cap nothing changes', () {
      final couple = CoupleRetirement.of(
        _projection(2000),
        _projection(1800),
        relationship: Relationship.married,
      );
      expect(couple.isCapped, isFalse);
      expect(couple.ahv, Money(3800));
    });
  });

  group('Household', () {
    test('splits shared bills by income or equally', () {
      final summary = HouseholdSummary.of(
        _anna,
        myNetWorth: Money(100000),
        myMonthlyIncome: Money(9350),
        sharedMonthlyBills: Money(1400),
      );
      expect(summary.netWorth, Money(100000 + 60000));
      expect(summary.myShare, closeTo(9350 / 14000, 1e-9));
      expect(summary.myPart + summary.partnerPart, Money(1400));

      final equal = HouseholdSummary.of(
        _anna.copyWith(splitRule: SplitRule.equal),
        myNetWorth: Money(100000),
        myMonthlyIncome: Money(9350),
        sharedMonthlyBills: Money(1400),
      );
      expect(equal.myPart, Money(700));
    });

    test('survives storage', () {
      final session = _plus.copyWith(
        household: _anna.copyWith(
          partnerRetirement: RetirementProfile.demo,
          splitRule: SplitRule.equal,
        ),
      );
      final restored = UserSession.decode(session.encode())!.household!;
      expect(restored.partnerName, 'Anna');
      expect(restored.relationship, Relationship.married);
      expect(restored.partnerNetWorth, Money(60000));
      expect(restored.partnerRetirement?.birthYear, 1988);
      expect(restored.splitRule, SplitRule.equal);
    });

    test('adds the partner to the user’s net worth', () async {
      final container = createTestContainer(
        session: _plus.copyWith(household: _anna),
      );
      final overview = await container.read(overviewProvider.future);
      final summary = await container.read(householdSummaryProvider.future);
      expect(summary!.netWorth, overview.total + Money(60000));
      expect(summary.sharedBills.isZero, isFalse);
      // No pension details yet: no couple projection.
      expect(await container.read(coupleRetirementProvider.future), isNull);

      container
          .read(sessionProvider.notifier)
          .setHousehold(_anna.copyWith(partnerRetirement: RetirementProfile.demo));
      final couple = await container.read(coupleRetirementProvider.future);
      expect(couple, isNotNull);
      expect(couple!.totalMonthly.cents, greaterThan(0));
    });
  });

  testWidgets('the household view is a Plus feature', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const HouseholdScreen()));
    await tester.pumpAndSettle();
    expect(find.text('See your household together'), findsOneWidget);
    expect(find.text('Unlock with Premium'), findsOneWidget);
  });

  testWidgets('a partner can be added and shows the combined view', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const HouseholdScreen(), session: _plus));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add partner'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Anna');
    await tester.enterText(fields.at(1), '4650');
    await tester.enterText(fields.at(2), '25000');
    final save = find.text('Save my figures');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Household net worth'), findsOneWidget);
    expect(find.text('Anna'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Add your partner’s pension details'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
