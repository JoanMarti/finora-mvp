import 'dart:convert';

import 'package:finora/app/theme.dart';
import 'package:finora/application/backend.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/data/api/api_client.dart';
import 'package:finora/data/api/http_backend_services.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/partners.dart';
import 'package:finora/domain/profile.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/offers/opportunities_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_helpers.dart';

final _consented = UserSession.demo().copyWith(offersConsent: true);

Future<List<Opportunity>> _detect(UserProfile profile) =>
    createTestContainer(
      session: _consented.copyWith(profile: profile),
    ).read(opportunitiesProvider.future);

class _Partners implements PartnerDirectory {
  @override
  Future<Map<OpportunityKind, PartnerLink>> links() async => {
    OpportunityKind.healthInsuranceSwitch: PartnerLink(
      kind: OpportunityKind.healthInsuranceSwitch,
      partnerName: 'Example Compare',
      url: Uri.parse('https://compare.example/kvg?aff=42'),
    ),
  };
}

void main() {
  group('Offers from the profile', () {
    test('renters with a blocked deposit see the guarantee option', () async {
      final found = await _detect(UserSession.demo().profile);
      final deposit = found.firstWhere(
        (item) => item.kind == OpportunityKind.rentDeposit,
      );
      expect(deposit.amount, const Money.cents(660000));
      expect(deposit.percent, 5);
      expect(deposit.savingHigh, isNull);

      final owners = await _detect(
        UserSession.demo().profile.copyWith(housing: Housing.owning),
      );
      expect(
        owners.map((item) => item.kind),
        isNot(contains(OpportunityKind.rentDeposit)),
      );
    });

    test('parents are reminded of the minimum child allowance', () async {
      final found = await _detect(
        UserSession.demo().profile.copyWith(children: 2),
      );
      final allowance = found.firstWhere(
        (item) => item.kind == OpportunityKind.familyAllowance,
      );
      expect(allowance.amount, const Money.cents(43000));
      expect(allowance.isSponsored, isFalse);
    });

    test('the self-employed see their larger Pillar 3a room', () async {
      final employee = await _detect(UserSession.demo().profile);
      final selfEmployed = await _detect(
        UserSession.demo().profile.copyWith(
          employment: Employment.selfEmployed,
        ),
      );
      Money room(List<Opportunity> items) => items
          .firstWhere((item) => item.kind == OpportunityKind.pillar3aRoom)
          .amount!;
      expect(room(selfEmployed).cents, greaterThan(room(employee).cents));
    });

    test('interests move related ideas up, never past deadlines', () async {
      final base = await _detect(
        UserSession.demo().profile.copyWith(interests: const {}),
      );
      final saver = await _detect(
        UserSession.demo().profile.copyWith(
          interests: const {Interest.saveMore},
        ),
      );
      int position(List<Opportunity> items, OpportunityKind kind) =>
          items.indexWhere((item) => item.kind == kind);
      expect(
        position(saver, OpportunityKind.savingsRate),
        lessThan(position(base, OpportunityKind.savingsRate)),
      );
      expect(saver.first.kind, OpportunityKind.healthInsuranceSwitch);
    });
  });

  group('Partner links', () {
    test('only https links are accepted and tracking is added', () {
      expect(
        PartnerLink.fromJson({
          'kind': 'telecomPlan',
          'partnerName': 'X',
          'url': 'http://x.example',
        }),
        isNull,
      );
      final link = PartnerLink.fromJson({
        'kind': 'telecomPlan',
        'partnerName': 'Example Mobile',
        'url': 'https://mobile.example/offer?aff=7',
      })!;
      final tracked = link.trackedUrl();
      expect(tracked.queryParameters['aff'], '7');
      expect(tracked.queryParameters['utm_source'], 'finora');
      expect(tracked.queryParameters['utm_campaign'], 'telecomPlan');
    });

    test('the backend list skips invalid rows', () async {
      final services = HttpBackendServices(
        FinoraApiClient(
          baseUrl: Uri.parse('https://api.test/'),
          client: MockClient(
            (request) async => http.Response(
              jsonEncode([
                {
                  'kind': 'rentDeposit',
                  'partnerName': 'Example Caution',
                  'url': 'https://caution.example',
                },
                {'kind': 'unknown', 'partnerName': 'Y', 'url': 'https://y.example'},
              ]),
              200,
            ),
          ),
        ),
      );
      final links = await services.links();
      expect(links.keys, [OpportunityKind.rentDeposit]);
    });
  });

  testWidgets('a configured partner opens its tracked link', (tester) async {
    usePhoneViewport(tester);
    Uri? opened;
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(session: _consented),
        partnerDirectoryProvider.overrideWithValue(_Partners()),
        linkOpenerProvider.overrideWithValue((uri) async {
          opened = uri;
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const OpportunitiesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare health insurance before 30 November'));
    await tester.pumpAndSettle();

    final action = find.widgetWithText(
      FilledButton,
      'Continue to Example Compare',
    );
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(opened?.host, 'compare.example');
    expect(opened?.queryParameters['aff'], '42');
    expect(opened?.queryParameters['utm_campaign'], 'healthInsuranceSwitch');
    expect(tester.takeException(), isNull);
  });
}
