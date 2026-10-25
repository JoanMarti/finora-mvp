import 'dart:convert';

import 'package:finora/app/bootstrap.dart';
import 'package:finora/application/backend.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/data/api/api_client.dart';
import 'package:finora/data/api/http_backend_services.dart';
import 'package:finora/data/remote_financial_repository.dart';
import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _money(int cents) => {'cents': cents, 'currency': 'CHF'};

/// A tiny fake backend answering the read endpoints of `docs/api.md`.
final _routes = <String, Object?>{
  '/api/v1/institutions': [
    {
      'id': 'ubs',
      'name': 'UBS',
      'connectionMethod': 'bLink',
      'productTypes': ['currentAccount', 'savings'],
    },
  ],
  '/api/v1/connections': [
    {
      'institutionId': 'ubs',
      'status': 'connected',
      'lastSyncedAt': '2026-10-23T08:00:00Z',
    },
  ],
  '/api/v1/accounts': [
    {
      'id': 'ubs-1',
      'institutionId': 'ubs',
      'name': 'Personal account',
      'type': 'currentAccount',
      'balance': _money(1248040),
    },
    {
      'id': 'ubs-mortgage',
      'institutionId': 'ubs',
      'name': 'Mortgage',
      'type': 'mortgage',
      'balance': _money(-48000000),
    },
  ],
  '/api/v1/accounts/ubs-1/analytics': {
    'monthlyIncome': _money(935000),
    'monthlySpending': _money(642600),
    'balanceHistory': [
      {'month': '2026-09-01', 'balance': _money(1200000)},
      {'month': '2026-10-01', 'balance': _money(1248040)},
    ],
    'cashFlowHistory': [
      {
        'month': '2026-10-01',
        'income': _money(935000),
        'spending': _money(642600),
      },
    ],
    'recurringPayments': [
      {
        'merchant': 'CSS Insurance',
        'category': 'healthInsurance',
        'amount': _money(-34820),
        'cadence': 'monthly',
        'nextDueAt': '2026-11-01',
      },
    ],
    'spendingCategories': [
      {'category': 'groceries', 'amount': _money(98000)},
    ],
  },
  '/api/v1/accounts/ubs-mortgage/analytics': {
    'monthlyIncome': _money(0),
    'monthlySpending': _money(0),
  },
  '/api/v1/transactions': [
    {
      'id': 't1',
      'accountId': 'ubs-1',
      'merchant': 'Migros',
      'category': 'groceries',
      'bookedAt': '2026-10-22T10:00:00Z',
      'amount': _money(-8540),
    },
  ],
  '/api/v1/pillar3a/contributions': {'amount': _money(400000)},
  '/api/v1/tax/2025': {
    'year': 2025,
    'asOf': '2025-12-31',
    'isComplete': true,
    'pillar3aContributions': _money(725800),
    'accounts': [
      {
        'accountId': 'ubs-1',
        'closingBalance': _money(1100000),
        'income': _money(1200),
      },
      {'accountId': 'closed-account', 'closingBalance': _money(5)},
    ],
  },
};

void main() {
  late List<http.Request> requests;

  FinoraApiClient api({Map<String, Object?>? routes, int status = 200}) {
    requests = [];
    return FinoraApiClient(
      baseUrl: Uri.parse('https://backend.test/api/'),
      accessToken: () async => 'token-123',
      client: MockClient((request) async {
        requests.add(request);
        final body = (routes ?? _routes)[request.url.path];
        if (request.method != 'GET') return http.Response('', 204);
        if (body == null) return http.Response('not found', 404);
        return http.Response(jsonEncode(body), status);
      }),
    );
  }

  group('Remote repository', () {
    test('maps every read endpoint to the domain', () async {
      final repository = RemoteFinancialRepository(api());

      final institutions = await repository.getInstitutions();
      expect(institutions.single.connectionMethod, ConnectionMethod.bLink);
      expect(institutions.single.shortName, 'UBS');

      final connections = await repository.getConnections();
      expect(connections.single.status, ConnectionStatus.connected);

      final accounts = await repository.getAccounts();
      expect(accounts.first.balance, Money(12480.40));
      expect(accounts.last.type, FinancialProductType.mortgage);
      expect(accounts.first.monthlyChange, Money.zero);

      final analytics = await repository.getAccountAnalytics('ubs-1');
      expect(analytics.savingsRate, closeTo(.3127, .001));
      expect(analytics.recurringPayments.single.isInsurance, isTrue);
      expect(analytics.balanceHistory, hasLength(2));

      final transactions = await repository.getTransactions(accountId: 'ubs-1');
      expect(transactions.single.merchant, 'Migros');
      expect(requests.last.url.queryParameters['accountId'], 'ubs-1');

      expect(
        await repository.getPillar3aContributions(year: 2026),
        Money(4000),
      );
      expect(requests.last.url.queryParameters['year'], '2026');

      final tax = await repository.getTaxYearData(2025);
      expect(tax.isComplete, isTrue);
      // Figures for accounts that no longer exist are skipped.
      expect(tax.accounts.single.account.id, 'ubs-1');
      expect(tax.accounts.single.income, Money(12));

      await repository.refresh();
      expect(requests.last.method, 'POST');
      expect(requests.last.url.path, '/api/v1/refresh');
    });

    test('sends the access token and asks for JSON', () async {
      await RemoteFinancialRepository(api()).getAccounts();
      expect(requests.single.headers['Authorization'], 'Bearer token-123');
      expect(requests.single.headers['Accept'], 'application/json');
    });

    test('server errors and malformed data become ApiException', () async {
      await expectLater(
        RemoteFinancialRepository(api(status: 401)).getAccounts(),
        throwsA(
          isA<ApiException>().having((e) => e.isUnauthorized, '401', isTrue),
        ),
      );
      final broken = {
        '/api/v1/accounts': [
          {'id': 'x', 'institutionId': 'ubs', 'name': 'X', 'type': 'yacht'},
        ],
      };
      await expectLater(
        RemoteFinancialRepository(api(routes: broken)).getAccounts(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('Backend services', () {
    const telecom = Opportunity(
      kind: OpportunityKind.telecomPlan,
      category: OpportunityCategory.telecom,
      revenue: RevenueModel.leadFee,
      priority: 2,
      savingLow: Money.cents(20000),
      savingHigh: Money.cents(40000),
    );

    test('the funnel report carries counts only', () async {
      final services = HttpBackendServices(api());
      await services.report(
        'abc',
        const FunnelStats().record(telecom, OfferEventType.partnerClicked),
      );
      final request = requests.single;
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/v1/installations/abc/funnel');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body.keys, {'counts', 'pursuedSavingLow', 'pursuedSavingHigh'});
      expect((body['counts']! as Map)['telecomPlan'], {'partnerClicked': 1});
    });

    test('reminders carry kind and date, never names or bills', () async {
      final services = HttpBackendServices(api());
      await services.syncReminders(
        'abc',
        [
          CalendarEvent(
            kind: CalendarEventKind.goalDeadline,
            date: DateTime(2027, 6, 30),
            subject: 'Wedding in Ticino',
            amount: Money(20000),
            route: '/goals',
          ),
          CalendarEvent(
            kind: CalendarEventKind.bill,
            date: DateTime(2026, 11, 1),
            subject: 'CSS Insurance',
            route: '/analysis',
          ),
        ],
        languageCode: 'de',
      );
      final body = jsonDecode(requests.single.body) as Map<String, Object?>;
      expect(body['language'], 'de');
      final reminders = body['reminders']! as List;
      expect(reminders, hasLength(1));
      final reminder = reminders.single as Map<String, Object?>;
      expect(reminder['kind'], 'goalDeadline');
      expect(reminder['date'], '2027-06-30');
      expect(requests.single.body, isNot(contains('Wedding')));
      expect(requests.single.body, isNot(contains('20000')));
    });
  });

  group('Bootstrap', () {
    test('the demo never talks to a backend', () {
      expect(finoraApiUrl, isEmpty);
      final container = ProviderContainer(overrides: demoOverrides());
      addTearDown(container.dispose);
      expect(container.read(backendEnabledProvider), isFalse);
      container.read(backendSyncProvider);
      expect(container.read(sessionProvider).installationId, isNull);
    });

    test('with a backend, reminders sync under an anonymous id', () async {
      final container = ProviderContainer(
        overrides: [
          ...backendOverrides(
            api(),
            sessionStore: InMemorySessionStore(
              UserSession.demo().copyWith(connectedInstitutionIds: {'ubs'}),
            ),
          ),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 12)),
        ],
      );
      addTearDown(container.dispose);
      container.read(backendSyncProvider);
      // Let the calendar load from the fake backend and the sync run.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final id = container.read(sessionProvider).installationId;
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      final sync = requests.where(
        (request) => request.url.path.endsWith('/reminders'),
      );
      expect(sync, isNotEmpty);
      expect(sync.last.url.path, '/api/v1/installations/$id/reminders');
      expect(sync.last.body, contains('healthInsuranceSwitch'));
    });
  });
}
