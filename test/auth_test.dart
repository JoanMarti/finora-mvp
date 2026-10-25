import 'dart:convert';

import 'package:finora/app/app.dart';
import 'package:finora/application/auth.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/data/api/api_client.dart';
import 'package:finora/data/api/http_auth_service.dart';
import 'package:finora/data/demo_auth_service.dart';
import 'package:finora/domain/auth.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_helpers.dart';

const _anna = Registration(
  firstName: 'Anna',
  email: 'Anna.Muster@finora.ch',
  password: 'Matterhorn2026',
  acceptedTermsVersion: termsVersion,
);

void main() {
  group('Password policy', () {
    test('explains what is missing', () {
      expect(PasswordPolicy.missing('abc'), [
        PasswordRule.length,
        PasswordRule.digit,
      ]);
      expect(PasswordPolicy.missing('1234567890'), [PasswordRule.letter]);
      expect(
        PasswordPolicy.missing('anna2026anna', email: 'anna@finora.ch'),
        [PasswordRule.notEmail],
      );
      expect(PasswordPolicy.accepts('Matterhorn2026'), isTrue);
    });

    test('rates strength', () {
      expect(PasswordPolicy.strength('short1'), PasswordStrength.weak);
      expect(PasswordPolicy.strength('alpine2026'), PasswordStrength.fair);
      expect(PasswordPolicy.strength('Matterhorn2026'), PasswordStrength.strong);
    });
  });

  group('Demo accounts', () {
    late InMemoryAccountStore store;
    late DemoAuthService auth;

    setUp(() {
      store = InMemoryAccountStore();
      auth = DemoAuthService(store);
    });

    test('register, verify and sign in', () async {
      final account = await auth.register(_anna);
      expect(account.email, 'anna.muster@finora.ch');
      expect(account.emailVerified, isFalse);
      // Only a hash is kept, never the password.
      expect(store.load(), isNot(contains('Matterhorn2026')));

      await expectLater(
        auth.register(_anna),
        throwsA(
          isA<AuthException>().having((e) => e.error, 'error', AuthError.emailTaken),
        ),
      );
      final verified = await auth.verifyEmail(
        'anna.muster@finora.ch',
        DemoAuthService.demoCode,
      );
      expect(verified.emailVerified, isTrue);

      final signedIn = await auth.signIn('ANNA.muster@finora.ch', 'Matterhorn2026');
      expect(signedIn.id, account.id);
      expect(signedIn.emailVerified, isTrue);
    });

    test('wrong passwords and codes are limited', () async {
      await auth.register(_anna);
      for (var i = 0; i < DemoAuthService.maxAttempts; i++) {
        await expectLater(
          auth.signIn(_anna.email, 'wrong'),
          throwsA(isA<AuthException>()),
        );
      }
      await expectLater(
        auth.signIn(_anna.email, _anna.password),
        throwsA(
          isA<AuthException>().having(
            (e) => e.error,
            'error',
            AuthError.tooManyAttempts,
          ),
        ),
      );
      for (var i = 0; i < DemoAuthService.maxAttempts; i++) {
        await expectLater(
          auth.verifyEmail(_anna.email, '000000'),
          throwsA(isA<AuthException>()),
        );
      }
      // A new code lifts the lockout.
      await auth.resendCode(_anna.email);
      final verified = await auth.verifyEmail(
        _anna.email,
        DemoAuthService.demoCode,
      );
      expect(verified.emailVerified, isTrue);
    });

    test('weak passwords never create an account', () async {
      await expectLater(
        auth.register(
          const Registration(
            firstName: 'Anna',
            email: 'anna@finora.ch',
            password: 'short',
            acceptedTermsVersion: termsVersion,
          ),
        ),
        throwsA(
          isA<AuthException>().having((e) => e.error, 'error', AuthError.weakPassword),
        ),
      );
      expect(store.load(), isNull);
    });
  });

  group('Backend accounts', () {
    test('map server codes and keep the access token', () async {
      final tokens = AuthTokenHolder();
      final api = FinoraApiClient(
        baseUrl: Uri.parse('https://api.test/'),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (request.url.path.endsWith('/register')) {
            return http.Response(
              jsonEncode({'error': 'taken', 'code': 'emailTaken'}),
              409,
            );
          }
          expect(body['email'], 'anna@finora.ch');
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'usr_1',
                'email': 'anna@finora.ch',
                'firstName': 'Anna',
                'emailVerified': true,
              },
              'accessToken': 'tok',
            }),
            200,
          );
        }),
      );
      final auth = HttpAuthService(api, tokens);
      await expectLater(
        auth.register(_anna),
        throwsA(
          isA<AuthException>().having((e) => e.error, 'error', AuthError.emailTaken),
        ),
      );
      final account = await auth.signIn(' Anna@finora.ch ', 'Matterhorn2026');
      expect(account.firstName, 'Anna');
      expect(await tokens.read(), 'tok');
    });
  });

  group('Session', () {
    test('signing up records the terms and keeps the profile', () {
      final container = createTestContainer(session: const UserSession());
      container
          .read(sessionProvider.notifier)
          .signedIn(
            const AuthAccount(
              id: 'usr_1',
              email: 'anna.muster@finora.ch',
              firstName: 'anna',
              emailVerified: false,
            ),
            acceptedTerms: true,
            marketingOptIn: true,
          );
      final session = container.read(sessionProvider);
      expect(session.displayName, 'Anna');
      expect(session.initials, 'AN');
      expect(session.hasAccount, isTrue);
      expect(session.marketingOptIn, isTrue);
      expect(
        session.consentLog.map((record) => record.purpose),
        [ConsentPurpose.terms, ConsentPurpose.marketing],
      );

      final restored = UserSession.decode(session.encode())!;
      expect(restored.userId, 'usr_1');
      expect(restored.firstName, 'anna');
      expect(restored.emailVerified, isFalse);
      expect(restored.consentLog.first.purpose, ConsentPurpose.terms);
    });
  });

  group('Screens', () {
    Future<ProviderContainer> pumpApp(
      WidgetTester tester, {
      required UserSession session,
      required AccountStore accounts,
    }) async {
      usePhoneViewport(tester, size: const Size(430, 932));
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(session: session),
          accountStoreProvider.overrideWithValue(accounts),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FinoraApp(),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('signing in continues with the setup', (tester) async {
      final accounts = InMemoryAccountStore();
      final auth = DemoAuthService(accounts);
      await auth.register(_anna);
      await auth.verifyEmail(_anna.email, DemoAuthService.demoCode);

      final container = await pumpApp(
        tester,
        session: const UserSession(languageCode: 'en'),
        accounts: accounts,
      );
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), 'anna.muster@finora.ch');
      await tester.enterText(fields.at(1), 'wrong-password1');
      await tester.pump();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('E-mail or password is not correct.'), findsOneWidget);

      await tester.enterText(fields.at(1), 'Matterhorn2026');
      await tester.pump();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Choose how to start'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Start free'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start free'));
      await tester.pumpAndSettle();
      expect(find.text('What do you have?'), findsOneWidget);
      expect(container.read(sessionProvider).firstName, 'Anna');
      expect(tester.takeException(), isNull);
    });

    testWidgets('signing out returns to the welcome screen', (tester) async {
      await pumpApp(
        tester,
        session: UserSession.demo().copyWith(
          languageCode: 'en',
          userId: 'usr_1',
          firstName: 'Anna',
          emailVerified: true,
        ),
        accounts: InMemoryAccountStore(),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('E-mail confirmed'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
    });
  });
}
