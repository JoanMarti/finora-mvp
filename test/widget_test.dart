import 'package:finora/app/app.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/accounts/account_detail_screen.dart';
import 'package:finora/features/accounts/accounts_screen.dart';
import 'package:finora/features/activity/activity_screen.dart';
import 'package:finora/features/overview/dashboard_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

void main() {
  testWidgets('onboarding branches into investments and Pillar 3a', (
    tester,
  ) async {
    usePhoneViewport(tester, size: const Size(430, 932));

    // A fresh install has no session, so the router starts onboarding.
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(session: const UserSession()),
        child: const FinoraApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your finances.\nOne clear view.'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'Anna');
    await tester.enterText(fields.at(1), 'anna');
    await tester.pump();
    expect(find.text('Enter a valid e-mail address'), findsOneWidget);
    await tester.enterText(fields.at(1), 'anna.muster@finora.ch');
    await tester.enterText(fields.at(2), 'Matterhorn2026');
    await tester.pump();
    expect(find.text('Strong'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // The 6-digit code confirms the address (the demo code is shown).
    expect(find.text('Check your inbox'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, '123456');
    await tester.pumpAndSettle();

    // Free or Premium trial: start free.
    expect(find.text('Choose how to start'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Start free'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Let the list come to rest: a tap on a moving list only stops it.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start free'));
    await tester.pumpAndSettle();

    expect(find.text('What do you have?'), findsOneWidget);
    await tester.tap(find.text('Current account'));
    await tester.tap(find.text('Investments'));
    await tester.tap(find.text('Pillar 3a'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Where do you bank?'), findsOneWidget);
    await tester.tap(find.text('PostFinance'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Where do you invest?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Where is your Pillar 3a?'), findsOneWidget);
    await tester.tap(find.text('VIAC'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your financial setup'), findsOneWidget);

    await tester.tap(find.text('Continue to connections'));
    await tester.pumpAndSettle();
    expect(find.text('PostFinance'), findsOneWidget);
    expect(find.text('VIAC'), findsOneWidget);
    expect(find.text('UBS'), findsNothing);

    await tester.tap(find.text('Connect and continue'));
    await tester.pumpAndSettle();

    // The overview now reflects exactly what was selected.
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('PostFinance'), findsOneWidget);
    expect(find.text('UBS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning users skip onboarding', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: const FinoraApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('wealth dashboard fits a compact mobile viewport', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const DashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(find.text('Financial health'), findsOneWidget);
    expect(find.text('Wealth evolution'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Your wealth plan'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Your wealth plan'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Ideas for you'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ideas for you'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Illustrative targets and ideas'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Illustrative targets and ideas'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows an empty state without connections', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _screen(
        const DashboardScreen(),
        session: const UserSession(onboardingCompleted: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No accounts connected yet'), findsOneWidget);
    expect(find.text('Your wealth plan'), findsNothing);
  });

  testWidgets('notification bell lists derived alerts', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const DashboardScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    // ZKB is stale in the demo data and CSS Insurance is due within a week.
    expect(find.text('Zürcher Kantonalbank data is out of date'), findsOneWidget);
    expect(find.text('CSS Insurance is due soon'), findsOneWidget);
  });

  testWidgets('account detail explains cash flow and improvement signals', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      _screen(const AccountDetailScreen(accountId: 'ubs-personal')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account insight'), findsOneWidget);
    expect(find.text('Balance evolution'), findsOneWidget);
    expect(find.text('6 months'), findsOneWidget);
    await tester.tap(find.text('3 months'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Cash flow'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Income vs spending'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Where your money went'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Housing'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Recurring payments'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('5 detected'), findsOneWidget);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Potential improvements'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Review insurance in one place'), findsOneWidget);
    expect(find.textContaining('2 insurance payments'), findsOneWidget);
    expect(find.text('See the true cost of your debt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accounts screen groups institutions and disconnects for real', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const AccountsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Your accounts, clearly organised'), findsOneWidget);
    expect(find.text('PORTFOLIO TOTAL'), findsOneWidget);
    expect(find.text('UBS'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions for Personal account'));
    await tester.pumpAndSettle();
    expect(find.text('Open UBS'), findsOneWidget);
    expect(find.text('Disconnect institution'), findsOneWidget);

    await tester.tap(find.text('Disconnect institution'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect UBS?'), findsOneWidget);
    expect(
      find.textContaining('Your accounts at the bank are not affected'),
      findsOneWidget,
    );
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('UBS'), findsNothing);
    expect(find.text('UBS disconnected.'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('UBS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity search filters transactions', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(_screen(const ActivityScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Migros'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'sbb');
    await tester.pumpAndSettle();
    expect(find.text('SBB Mobile'), findsOneWidget);
    expect(find.text('Migros'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'nothing-matches');
    await tester.pumpAndSettle();
    expect(find.textContaining('No transactions match'), findsOneWidget);
  });

  testWidgets('the app speaks German when chosen', (tester) async {
    usePhoneViewport(tester);
    addTearDown(() => Intl.defaultLocale = null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          session: UserSession.demo().copyWith(languageCode: 'de'),
        ),
        child: const FinoraApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('GESAMTVERMÖGEN'), findsOneWidget);
    expect(find.text('Konten'), findsOneWidget);
    expect(find.text('TOTAL WEALTH'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language can be changed from the profile', (tester) async {
    usePhoneViewport(tester);
    addTearDown(() => Intl.defaultLocale = null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          session: UserSession.demo().copyWith(languageCode: 'en'),
        ),
        child: const FinoraApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    final languageTile = find.widgetWithText(ListTile, 'Language');
    await tester.dragUntilVisible(
      languageTile,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.ensureVisible(languageTile);
    await tester.pumpAndSettle();
    await tester.tap(languageTile);
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsOneWidget);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsWidgets);
    expect(find.text('Comptes'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
