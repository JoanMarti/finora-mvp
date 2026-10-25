import 'package:finora/app/app.dart';
import 'package:finora/app/layout.dart';
import 'package:finora/app/router.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Future<ProviderContainer> _pumpApp(WidgetTester tester, Size size) async {
  usePhoneViewport(tester, size: size);
  final container = createTestContainer(
    session: UserSession.demo().copyWith(languageCode: 'en'),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const FinoraApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

const _desktop = Size(1440, 900);

void main() {
  test('window classes follow the width', () {
    expect(FinoraWindow.forWidth(390), FinoraWindow.compact);
    expect(FinoraWindow.forWidth(900), FinoraWindow.medium);
    expect(FinoraWindow.forWidth(1440), FinoraWindow.expanded);
  });

  test('detail pages belong to their section', () {
    expect(navSectionOf('/account/ubs-savings'), '/accounts');
    expect(navSectionOf('/institution/ubs'), '/accounts');
    expect(navSectionOf('/offers'), '/offers');
  });

  test('the sidebar lists every section once', () {
    final routes = [
      for (final group in sidebarNavGroups)
        for (final item in group.items) item.route,
    ];
    expect(routes.toSet().length, routes.length);
    expect(routes, containsAll(primaryNavItems.map((item) => item.route)));
  });

  testWidgets('phones keep the bottom bar on main pages only', (tester) async {
    final container = await _pumpApp(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);

    container.read(routerProvider).push('/goals');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('tablets get a navigation rail', (tester) async {
    await _pumpApp(tester, const Size(900, 1200));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('desktop shows every section in the sidebar', (tester) async {
    final container = await _pumpApp(tester, _desktop);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('SAVE'), findsOneWidget);

    await tester.tap(find.text('Savings offers'));
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routerDelegate.currentConfiguration.uri
          .path,
      '/offers',
    );
    // The sidebar stays on screen on every page.
    expect(find.text('Savings offers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop accounts show list and detail side by side', (
    tester,
  ) async {
    final container = await _pumpApp(tester, _desktop);
    container.read(routerProvider).go('/accounts');
    await tester.pumpAndSettle();
    // The first account opens next to the list.
    expect(find.text('Account insight'), findsOneWidget);

    await tester.ensureVisible(find.text('Vitainvest 3a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vitainvest 3a'));
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routerDelegate.currentConfiguration.uri
          .path,
      '/accounts',
    );
    expect(find.text('Vitainvest 3a'), findsAtLeastNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop activity reads as a table', (tester) async {
    final container = await _pumpApp(tester, _desktop);
    container.read(routerProvider).go('/activity');
    await tester.pumpAndSettle();
    expect(find.text('DATE'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop dashboard renders in two columns', (tester) async {
    await _pumpApp(tester, _desktop);
    expect(find.text('Planning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop simulators show inputs and result side by side', (
    tester,
  ) async {
    final container = await _pumpApp(tester, _desktop);
    container.read(routerProvider).go('/home-buying');
    await tester.pumpAndSettle();
    final result = tester.getTopLeft(find.text('Highest affordable price'));
    final income = tester.getTopLeft(find.text('Gross household income per year'));
    // Result on the right, first input on the left, both on screen.
    expect(result.dx, greaterThan(income.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-up on desktop sits next to the brand panel', (
    tester,
  ) async {
    usePhoneViewport(tester, size: _desktop);
    final container = createTestContainer(
      session: const UserSession(languageCode: 'en'),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FinoraApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your Swiss wealth, in one place'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
