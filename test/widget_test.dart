import 'package:finora/app/app.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/features/accounts/accounts_screens.dart';
import 'package:finora/features/overview/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding branches into investments and Pillar 3a', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: FinoraApp()));
    expect(find.text('Your finances.\nOne clear view.'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'demo@finora.ch');
    await tester.pump();
    await tester.tap(find.text('Create mock account'));
    await tester.pumpAndSettle();

    expect(find.text('What do you have?'), findsOneWidget);
    await tester.tap(find.text('Current account'));
    await tester.tap(find.text('Investments'));
    await tester.tap(find.text('Pillar 3a'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Where do you bank?'), findsOneWidget);
    await tester.tap(find.text('UBS'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Where do you invest?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Where is your Pillar 3a?'), findsOneWidget);
  });

  testWidgets('wealth dashboard fits a compact mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildFinoraTheme(),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TOTAL WEALTH'), findsOneWidget);
    expect(find.text('Wealth evolution'), findsOneWidget);
    expect(find.text('YOUR WEALTH PLAN'), findsOneWidget);
    expect(find.text('Total balance breakdown'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    expect(find.text('IDEAS FOR YOU'), findsOneWidget);
    expect(
      find.textContaining('Illustrative targets and ideas'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('account detail explains cash flow and improvement signals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildFinoraTheme(),
          home: const AccountDetailScreen(accountId: 'ubs-personal'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account insight'), findsOneWidget);
    expect(find.text('Balance evolution'), findsOneWidget);
    expect(find.text('6 months'), findsOneWidget);
    await tester.tap(find.text('3 months'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('CASH FLOW'),
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
    expect(find.text('Where your money went'), findsOneWidget);
    expect(find.text('Housing'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('RECURRING PAYMENTS'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('5 detected'), findsOneWidget);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('POTENTIAL IMPROVEMENTS'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Review insurance in one place'), findsOneWidget);
    expect(find.text('See the true cost of your debt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accounts screen groups institutions and exposes safe actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildFinoraTheme(),
          home: const AccountsScreen(),
        ),
      ),
    );
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
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
