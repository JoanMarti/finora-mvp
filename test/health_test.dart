import 'package:finora/app/theme.dart';
import 'package:finora/application/health.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/domain/health.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/assets/assets_screen.dart';
import 'package:finora/features/health/health_screen.dart';
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

const _healthyOverview = FinancialOverview(
  cash: Money.cents(5000000),
  savings: Money.cents(3600000),
  investments: Money.cents(2000000),
  retirement: Money.cents(3000000),
  liabilities: Money.zero,
  history: [],
  monthlySpending: Money.cents(500000),
  pillar3aContributionsThisYear: Money.cents(725800),
);

HealthInput _input({
  FinancialOverview overview = _healthyOverview,
  Money mortgage = Money.zero,
  Money property = Money.zero,
  double savingsRate = .25,
  double fixedShare = .4,
  double coverage = 1.1,
}) => HealthInput(
  overview: overview,
  targets: const WealthTargets(),
  monthlyIncome: const Money.cents(1000000),
  savingsRate: savingsRate,
  fixedCostShare: fixedShare,
  mortgageDebt: mortgage,
  propertyValue: property,
  retirementCoverage: coverage,
  retirementIsExample: false,
  hasPillar3a: true,
);

final _property = ManualAsset(
  id: 'flat',
  kind: ManualAssetKind.property,
  name: 'Flat in Winterthur',
  value: const Money.cents(75000000),
  valuedAt: testNow,
);

/// The demo profile plus Raiffeisen, which holds the demo mortgage.
final _withMortgage = UserSession.demo().copyWith(
  connectedInstitutionIds: {
    ...UserSession.demo().connectedInstitutionIds,
    'raiffeisen',
  },
);

void main() {
  group('Financial health', () {
    test('a healthy profile scores 100 with no next step', () {
      final health = FinancialHealth.of(_input());
      expect(health.score, 100);
      expect(health.status, HealthStatus.good);
      expect(health.nextStep, isNull);
      // No mortgage, so housing is not judged.
      expect(
        health.factors.map((factor) => factor.kind),
        isNot(contains(HealthFactorKind.housing)),
      );
    });

    test('the next step is where acting gains the most points', () {
      final health = FinancialHealth.of(_input(savingsRate: .05));
      expect(health.nextStep?.kind, HealthFactorKind.savingsRate);
      expect(health.score, lessThan(100));
    });

    test('a mortgage without a property value asks for the value', () {
      final health = FinancialHealth.of(
        _input(mortgage: const Money.cents(48000000)),
      );
      final housing = health.factors.firstWhere(
        (factor) => factor.kind == HealthFactorKind.housing,
      );
      expect(housing.status, HealthStatus.missingData);
      expect(housing.route, '/assets');
      // Missing data does not lower the score...
      expect(health.score, 100);
      // ...but it becomes the next step once everything else is fine.
      expect(health.nextStep?.kind, HealthFactorKind.housing);
    });

    test('housing follows Swiss loan-to-value and affordability rules', () {
      HealthFactor housing(int mortgageFrancs) =>
          FinancialHealth.of(
            _input(
              mortgage: Money.cents(mortgageFrancs * 100),
              property: const Money.cents(75000000),
            ),
          ).factors.firstWhere(
            (factor) => factor.kind == HealthFactorKind.housing,
          );

      // 480k on 750k: 64 % LTV; (24k + 7.5k) / 120k = 26 % of income.
      final comfortable = housing(480000);
      expect(comfortable.ratio, closeTo(.64, .001));
      expect(comfortable.secondRatio, closeTo(.2625, .001));
      expect(comfortable.status, HealthStatus.good);

      // 580k: 77 % LTV and 30.4 % of income → second mortgage, fair.
      expect(housing(580000).status, HealthStatus.fair);

      // 650k: 87 % LTV, beyond what banks lend.
      expect(housing(650000).status, HealthStatus.attention);
    });

    test('demo profile is scored from the connected data', () async {
      final container = createTestContainer(session: _withMortgage);
      final health = await container.read(financialHealthProvider.future);
      expect(health.score, inInclusiveRange(1, 100));
      final kinds = health.factors.map((factor) => factor.kind);
      expect(kinds, containsAll(HealthFactorKind.values));
      expect(
        health.factors
            .firstWhere((factor) => factor.kind == HealthFactorKind.housing)
            .status,
        HealthStatus.missingData,
      );
    });
  });

  group('Manual assets', () {
    test('count towards net worth and unlock the housing check', () async {
      final container = createTestContainer(session: _withMortgage);
      final before = await container.read(overviewProvider.future);
      container.read(sessionProvider.notifier).saveAsset(_property);

      final after = await container.read(overviewProvider.future);
      expect(after.total - before.total, _property.value);
      expect(after.otherAssets, _property.value);
      // Allocation shares stay on financial assets only.
      expect(after.assets, before.assets);
      expect(after.history.last.balance - before.history.last.balance,
          _property.value);

      final health = await container.read(financialHealthProvider.future);
      final housing = health.factors.firstWhere(
        (factor) => factor.kind == HealthFactorKind.housing,
      );
      expect(housing.status, isNot(HealthStatus.missingData));
      expect(housing.ratio, closeTo(.64, .001));
    });

    test('edit, delete and storage', () {
      final container = createTestContainer();
      final controller = container.read(sessionProvider.notifier)
        ..saveAsset(_property)
        ..saveAsset(_property.copyWith(value: const Money.cents(80000000)));
      var session = container.read(sessionProvider);
      expect(session.manualAssets, hasLength(1));
      expect(session.manualAssets.single.value, Money(800000));

      final restored = UserSession.decode(session.encode())!;
      expect(restored.manualAssets.single.name, 'Flat in Winterthur');
      expect(restored.manualAssets.single.kind, ManualAssetKind.property);

      controller.deleteAsset('flat');
      session = container.read(sessionProvider);
      expect(session.manualAssets, isEmpty);
    });

    test('crypto values age faster than property', () {
      final later = testNow.add(const Duration(days: 45));
      expect(_property.isOutdated(later), isFalse);
      expect(
        _property.copyWith(kind: ManualAssetKind.crypto).isOutdated(later),
        isTrue,
      );
    });
  });

  testWidgets('health screen explains every area', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _screen(const HealthScreen(), session: _withMortgage),
    );
    await tester.pumpAndSettle();

    expect(find.text('Financial health'), findsOneWidget);
    expect(find.textContaining('/ 100'), findsOneWidget);
    expect(find.text('Emergency fund'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Add property value'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mortgage & housing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an asset can be added from the assets screen', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const AssetsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Add your home'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Flat in Winterthur');
    await tester.enterText(fields.at(1), '750000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Flat in Winterthur'), findsOneWidget);
    final session = ProviderScope.containerOf(
      tester.element(find.byType(AssetsScreen)),
    ).read(sessionProvider);
    expect(session.manualAssets.single.value, Money(750000));
    expect(tester.takeException(), isNull);
  });
}
