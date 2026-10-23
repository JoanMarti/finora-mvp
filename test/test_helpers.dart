import 'package:finora/app/bootstrap.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/user_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed "now" so generated demo data is deterministic in tests.
final testNow = DateTime(2026, 10, 23, 12);

List<Override> testOverrides({UserSession? session, SessionStore? store}) => [
  ...demoOverrides(
    sessionStore: store ?? InMemorySessionStore(session ?? UserSession.demo()),
  ),
  clockProvider.overrideWithValue(() => testNow),
];

ProviderContainer createTestContainer({
  UserSession? session,
  SessionStore? store,
}) {
  final container = ProviderContainer(
    overrides: testOverrides(session: session, store: store),
  );
  addTearDown(container.dispose);
  return container;
}

void usePhoneViewport(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
