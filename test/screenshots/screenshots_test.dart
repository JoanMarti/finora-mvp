// Renders the main screens to PNG files in docs/screenshots so design
// changes can be reviewed on the pull request. Runs only when asked:
//
//   SCREENSHOTS=1 flutter test --update-goldens test/screenshots
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:finora/app/app.dart';
import 'package:finora/app/router.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../test_helpers.dart';

final _enabled = Platform.environment['SCREENSHOTS'] == '1';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Inter', [
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ])
      'assets/fonts/Inter-$weight.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    await load('MaterialIcons', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  }
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });
  tearDown(() => Intl.defaultLocale = null);

  final session = UserSession.demo().copyWith(
    languageCode: 'en',
    offersConsent: true,
    plan: FinoraPlan.plus,
  );

  Future<void> capture(
    WidgetTester tester,
    String name, {
    String? route,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: testOverrides(session: session),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FinoraApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (route != null) {
      container.read(routerProvider).go(route);
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(FinoraApp),
      matchesGoldenFile('../../docs/screenshots/$name.png'),
    );
  }

  const screens = {
    'dashboard': null,
    'accounts': '/accounts',
    'activity': '/activity',
    'profile': '/profile',
    'analysis': '/analysis',
    'health': '/health',
    'offers': '/offers',
    'calendar': '/calendar',
    'report': '/report',
    'plus': '/plus',
    'home-buying': '/home-buying',
  };

  for (final entry in screens.entries) {
    testWidgets(entry.key, (tester) async {
      await capture(tester, entry.key, route: entry.value);
    }, skip: !_enabled);
  }

  testWidgets('dashboard-full', (tester) async {
    await capture(tester, 'dashboard-full', size: const Size(390, 3200));
  }, skip: !_enabled);
}
