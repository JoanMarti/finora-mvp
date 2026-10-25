import 'dart:convert';
import 'dart:io';

import 'package:finora_server/finora_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Map<String, Object?> fixtures;
  late InstallationStore store;
  late Handler handler;

  setUpAll(() async {
    fixtures =
        jsonDecode(await File('fixtures/demo.json').readAsString())
            as Map<String, Object?>;
  });

  setUp(() {
    store = InstallationStore();
    handler = buildHandler(fixtures, store: store);
  });

  Future<(int, Object?)> call(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
    Handler? using,
  }) async {
    final response = await (using ?? handler)(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
        headers: headers,
      ),
    );
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  group('read endpoints', () {
    test('serve the demo profile', () async {
      final (status, accounts) = await call('GET', '/v1/accounts');
      expect(status, 200);
      expect((accounts! as List).map((item) => (item as Map)['id']),
          contains('raiffeisen-mortgage'));
      final (_, institutions) = await call('GET', '/v1/institutions');
      expect(institutions, isNotEmpty);
      final (_, connections) = await call('GET', '/v1/connections');
      expect(connections, isNotEmpty);
    });

    test('analytics follow the months parameter', () async {
      final accountId =
          ((fixtures['accounts']! as List).first as Map)['id'] as String;
      final (_, six) = await call('GET', '/v1/accounts/$accountId/analytics');
      expect(((six! as Map)['balanceHistory'] as List).length, 6);
      final (_, long) = await call(
        'GET',
        '/v1/accounts/$accountId/analytics?months=24',
      );
      expect(((long! as Map)['balanceHistory'] as List).length, 24);
      final (bad, _) = await call(
        'GET',
        '/v1/accounts/$accountId/analytics?months=99',
      );
      expect(bad, 400);
      final (missing, _) = await call('GET', '/v1/accounts/nope/analytics');
      expect(missing, 404);
    });

    test('filters transactions and serves yearly figures', () async {
      final (_, all) = await call('GET', '/v1/transactions');
      final accountId = ((all! as List).first as Map)['accountId'];
      final (_, filtered) = await call(
        'GET',
        '/v1/transactions?accountId=$accountId',
      );
      expect(
        (filtered! as List).every((item) => (item as Map)['accountId'] == accountId),
        isTrue,
      );
      expect((filtered as List).length, lessThanOrEqualTo(all.length));

      final (status, pillar) = await call(
        'GET',
        '/v1/pillar3a/contributions?year=2026',
      );
      expect(status, 200);
      expect(((pillar! as Map)['amount'] as Map)['cents'], isA<int>());
      final (taxStatus, tax) = await call('GET', '/v1/tax/2025');
      expect(taxStatus, 200);
      expect((tax! as Map)['isComplete'], isTrue);
      final (refresh, _) = await call('POST', '/v1/refresh');
      expect(refresh, 204);
    });
  });

  group('write endpoints keep personal data out', () {
    test('the funnel accepts aggregated fields only', () async {
      final (ok, _) = await call(
        'PUT',
        '/v1/installations/abc/funnel',
        body: {
          'counts': {
            'telecomPlan': {'viewed': 2},
          },
          'pursuedSavingLow': 0,
          'pursuedSavingHigh': 0,
        },
      );
      expect(ok, 204);
      expect(store.funnels['abc']?['counts'], isNotNull);

      final (rejected, _) = await call(
        'PUT',
        '/v1/installations/abc/funnel',
        body: {'counts': {}, 'email': 'demo@finora.ch'},
      );
      expect(rejected, 422);
    });

    test('reminders carry only id, kind and date', () async {
      final (ok, _) = await call(
        'PUT',
        '/v1/installations/abc/reminders',
        body: {
          'language': 'de',
          'reminders': [
            {'id': 'taxReturn-2027-03-31-0', 'kind': 'taxReturn', 'date': '2027-03-31'},
          ],
        },
      );
      expect(ok, 204);
      final (rejected, _) = await call(
        'PUT',
        '/v1/installations/abc/reminders',
        body: {
          'reminders': [
            {'id': 'x', 'kind': 'goalDeadline', 'date': '2027-06-30', 'name': 'Wedding'},
          ],
        },
      );
      expect(rejected, 422);
    });

    test('device tokens and purchase checks', () async {
      final (device, _) = await call(
        'PUT',
        '/v1/installations/abc/device',
        body: {'platform': 'ios', 'pushToken': 'token'},
      );
      expect(device, 204);
      final (status, verification) = await call(
        'POST',
        '/v1/purchases/verify',
        body: {'platform': 'ios', 'receipt': 'r'},
      );
      expect(status, 200);
      expect((verification! as Map)['active'], isFalse);
    });
  });

  test('an access token is enforced when configured', () async {
    final secured = buildHandler(fixtures, accessToken: 's3cret');
    final (denied, _) = await call('GET', '/v1/accounts', using: secured);
    expect(denied, 401);
    final (allowed, _) = await call(
      'GET',
      '/v1/accounts',
      using: secured,
      headers: {'authorization': 'Bearer s3cret'},
    );
    expect(allowed, 200);
  });
}
