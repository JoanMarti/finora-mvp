import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/pillar3a_catch_up.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/simulators/pillar3a_catch_up_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const _max = Money.cents(725800);

Pillar3aCatchUpPlan _plan(
  int year,
  Map<int, Money> paid, {
  Money paidThisYear = _max,
}) => Pillar3aCatchUpPlan.build(
  year: year,
  paidByYear: paid,
  currentMaximum: _max,
  paidThisYear: paidThisYear,
);

void main() {
  group('Pillar 3a catch-up', () {
    test('only gaps from 2025 on count', () {
      final plan = _plan(2026, {2025: const Money.cents(300000)});
      expect(plan.gaps.map((gap) => gap.year), [2025]);
      expect(plan.totalGap, const Money.cents(425800));
      expect(plan.purchasableThisYear, const Money.cents(425800));
      expect(plan.gaps.single.lastYear, 2035);
    });

    test('a purchase is capped at one small maximum per year', () {
      final plan = _plan(2028, {2025: Money.zero, 2026: Money.zero});
      // 2025, 2026 and 2027 are gaps (2027 nothing paid).
      expect(plan.gaps, hasLength(3));
      expect(plan.totalGap, const Money.cents(725800 * 3));
      expect(plan.purchasableThisYear, _max);
    });

    test('gaps older than ten years drop out', () {
      final plan = _plan(2037, const {});
      expect(plan.gaps.first.year, 2027);
      expect(plan.gaps, hasLength(10));
    });

    test('this year must be paid in full first', () {
      final plan = _plan(
        2026,
        const {},
        paidThisYear: const Money.cents(500000),
      );
      expect(plan.currentYearFull, isFalse);
      expect(plan.currentYearRoom, const Money.cents(225800));
      expect(_plan(2026, const {}).currentYearFull, isTrue);
    });

    test('tax saving at the marginal rate', () {
      final plan = _plan(2026, const {});
      expect(plan.taxSaving(.25), const Money.cents(181450));
      expect(plan.deadline, DateTime(2026, 12, 31));
    });

    test('no gaps when every year was paid in full', () {
      final plan = _plan(2026, {2025: _max});
      expect(plan.purchasableThisYear, Money.zero);
    });
  });

  testWidgets('the screen lets the user correct a past year', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(session: UserSession.demo()),
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Pillar3aCatchUpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pillar 3a catch-up'), findsOneWidget);
    final field = find.byType(TextField).first;
    await tester.enterText(field, '1000');
    await tester.pumpAndSettle();
    expect(find.textContaining('You can catch up'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
