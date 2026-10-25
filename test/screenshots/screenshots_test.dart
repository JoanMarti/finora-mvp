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
import 'package:flutter/rendering.dart';
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

Future<void> _renderScreen(
  WidgetTester tester,
  UserSession session,
  String name, {
  String? route,
  required Size size,
  String? goldenPath,
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
    matchesGoldenFile(goldenPath ?? '../../docs/screenshots/$name.png'),
  );
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
    UserSession? as,
    String? goldenPath,
  }) async {
    // Tests draw shadows without blur; draw them as on a phone. The flag is
    // restored before the test ends because the framework checks it.
    debugDisableShadows = false;
    try {
      await _renderScreen(
        tester,
        as ?? session,
        name,
        route: route,
        size: size,
        goldenPath: goldenPath,
      );
    } finally {
      debugDisableShadows = true;
    }
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
    'about-you': '/about-you',
  };

  for (final entry in screens.entries) {
    testWidgets(entry.key, (tester) async {
      await capture(tester, entry.key, route: entry.value);
    }, skip: !_enabled);
  }

  testWidgets('dashboard-full', (tester) async {
    await capture(tester, 'dashboard-full', size: const Size(390, 3200));
  }, skip: !_enabled);

  testWidgets('account-detail', (tester) async {
    await capture(tester, 'account-detail', route: '/account/ubs-savings');
  }, skip: !_enabled);

  // The web experience on a laptop and a tablet.
  const desktop = {
    'desktop-dashboard': null,
    'desktop-accounts': '/accounts',
    'desktop-activity': '/activity',
    'desktop-offers': '/offers',
  };
  for (final entry in desktop.entries) {
    testWidgets(entry.key, (tester) async {
      await capture(
        tester,
        entry.key,
        route: entry.value,
        size: const Size(1440, 900),
      );
    }, skip: !_enabled);
  }

  // Sign-up and plans, as a new user sees them.
  const newUser = UserSession(languageCode: 'en');
  final freeUser = UserSession.demo().copyWith(languageCode: 'en');
  testWidgets('welcome', (tester) async {
    await capture(tester, 'welcome', as: newUser);
  }, skip: !_enabled);
  testWidgets('sign-in', (tester) async {
    await capture(tester, 'sign-in', route: '/sign-in', as: newUser);
  }, skip: !_enabled);
  testWidgets('plans', (tester) async {
    await capture(tester, 'plans', route: '/plus', as: freeUser);
  }, skip: !_enabled);
  testWidgets('desktop-plans', (tester) async {
    await capture(
      tester,
      'desktop-plans',
      route: '/plus',
      as: freeUser,
      size: const Size(1440, 900),
    );
  }, skip: !_enabled);

  testWidgets('desktop-home-buying', (tester) async {
    await capture(
      tester,
      'desktop-home-buying',
      route: '/home-buying',
      size: const Size(1440, 900),
    );
  }, skip: !_enabled);
  testWidgets('desktop-welcome', (tester) async {
    await capture(
      tester,
      'desktop-welcome',
      as: newUser,
      size: const Size(1440, 900),
    );
  }, skip: !_enabled);

  // Google Play phone screenshots: 1080×1920 (9:16), English and German.
  const storeScreens = {
    '1_overview': null,
    '2_analysis': '/analysis',
    '3_savings': '/account/ubs-savings',
    '4_calendar': '/calendar',
    '5_home': '/home-buying',
    '6_plans': '/plus',
  };
  for (final locale in ['en-US', 'de-DE']) {
    final storeSession = UserSession.demo().copyWith(
      languageCode: locale.substring(0, 2),
      offersConsent: true,
      firstName: 'Anna',
    );
    for (final entry in storeScreens.entries) {
      testWidgets('store $locale ${entry.key}', (tester) async {
        await capture(
          tester,
          entry.key,
          route: entry.value,
          as: storeSession,
          size: const Size(540, 960),
          goldenPath:
              '../../fastlane/metadata/android/$locale/images/'
              'phoneScreenshots/${entry.key}.png',
        );
      }, skip: !_enabled);
    }
  }

  testWidgets('tablet-dashboard', (tester) async {
    await capture(tester, 'tablet-dashboard', size: const Size(900, 1200));
  }, skip: !_enabled);
}
