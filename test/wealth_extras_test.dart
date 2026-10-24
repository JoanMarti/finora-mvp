import 'package:finora/app/app.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/planning/tax_summary_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/formatters.dart';
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

ManualAsset _flat({DateTime? valuedAt}) => ManualAsset(
  id: 'flat',
  kind: ManualAssetKind.property,
  name: 'Flat in Winterthur',
  value: const Money.cents(75000000),
  valuedAt: valuedAt ?? testNow,
);

void main() {
  group('Hide amounts', () {
    tearDown(() => AmountPrivacy.hidden = false);

    test('masks every money format', () {
      AmountPrivacy.hidden = true;
      expect(formatMoney(Money(12480.4)), 'CHF •••');
      expect(formatMoneyWhole(Money(3250)), 'CHF •••');
      expect(formatCompactMoney(Money(44800), signed: true), 'CHF •••');
      AmountPrivacy.hidden = false;
      expect(formatMoney(Money(12480.4)), "CHF 12'480.40");
    });

    testWidgets('the dashboard eye toggles every amount', (tester) async {
      usePhoneViewport(tester);
      addTearDown(() => AmountPrivacy.hidden = false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(
            session: UserSession.demo().copyWith(languageCode: 'en'),
          ),
          child: const FinoraApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CHF •••'), findsNothing);

      await tester.tap(find.byTooltip('Hide amounts'));
      await tester.pumpAndSettle();
      expect(find.text('CHF •••'), findsWidgets);
      expect(find.text('TOTAL WEALTH'), findsOneWidget);

      await tester.tap(find.byTooltip('Show amounts'));
      await tester.pumpAndSettle();
      expect(find.text('CHF •••'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Property in other features', () {
    test('the mortgage offer explains the loan-to-value', () async {
      final found = OpportunityEngine.detect(
        OpportunityInput(
          accounts: const [
            FinancialAccount(
              id: 'm',
              institutionId: 'raiffeisen',
              name: 'Fixed-rate mortgage',
              type: FinancialProductType.mortgage,
              balance: Money.cents(-55000000),
              maskedIdentifier: '',
              monthlyChange: Money.zero,
            ),
          ],
          analytics: const {},
          pillar3aContributionsThisYear: Money.zero,
          now: testNow,
          propertyValue: const Money.cents(75000000),
        ),
      );
      final mortgage = found.firstWhere(
        (item) => item.kind == OpportunityKind.mortgageRenewal,
      );
      expect(mortgage.percent, 73);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final reason = l10n.opportunityReason(mortgage);
      expect(reason, contains('loan-to-value is 73%'));
      expect(reason, contains('indirect amortisation'));
    });

    test('an outdated estimate raises an alert', () async {
      final container = createTestContainer(
        session: UserSession.demo().copyWith(
          manualAssets: [
            _flat(valuedAt: testNow.subtract(const Duration(days: 400))),
          ],
        ),
      );
      final alerts = await container.read(alertsProvider.future);
      final asset = alerts.firstWhere(
        (alert) => alert.kind == AlertKind.assetValueOutdated,
      );
      expect(asset.subject, 'Flat in Winterthur');
      expect(asset.route, '/assets');
    });

    test('a fresh estimate does not', () async {
      final container = createTestContainer(
        session: UserSession.demo().copyWith(manualAssets: [_flat()]),
      );
      final alerts = await container.read(alertsProvider.future);
      expect(
        alerts.map((alert) => alert.kind),
        isNot(contains(AlertKind.assetValueOutdated)),
      );
    });

    testWidgets('the tax summary lists entered assets with guidance', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await tester.pumpWidget(
        _screen(
          const TaxSummaryScreen(),
          session: UserSession.demo().copyWith(manualAssets: [_flat()]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('imputed rental value'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ASSETS YOU ENTERED'), findsOneWidget);
      expect(find.text('Flat in Winterthur · Property'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
