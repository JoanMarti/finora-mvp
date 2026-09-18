import 'package:finora/app/app.dart';
import 'package:finora/app/theme.dart';
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
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    expect(find.text('EXPLORE SWISS OPPORTUNITIES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
