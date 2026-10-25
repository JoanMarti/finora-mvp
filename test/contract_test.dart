import 'dart:convert';
import 'dart:io';

import 'package:finora/data/api/api_client.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/data/remote_financial_repository.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/api_encoding.dart';
import 'test_helpers.dart';

/// Shared with the reference backend in `server/`.
final _fixtureFile = File('server/fixtures/demo.json');

/// Serves the fixture like the reference backend does.
http.Client _fakeBackend(Map<String, Object?> fixture) => MockClient((request) async {
  final path = request.url.path;
  final query = request.url.queryParameters;
  Object? body;
  if (path == '/v1/institutions') body = fixture['institutions'];
  if (path == '/v1/connections') body = fixture['connections'];
  if (path == '/v1/accounts') body = fixture['accounts'];
  if (path == '/v1/transactions') {
    body = [
      for (final item in fixture['transactions']! as List)
        if (query['accountId'] == null ||
            (item as Map)['accountId'] == query['accountId'])
          item,
    ];
  }
  final analytics = RegExp(r'^/v1/accounts/(.+)/analytics$').firstMatch(path);
  if (analytics != null) {
    body = (fixture['analytics']! as Map)[analytics.group(1)];
  }
  if (path == '/v1/pillar3a/contributions') {
    body = {'amount': (fixture['pillar3aContributions']! as Map)[query['year']]};
  }
  final tax = RegExp(r'^/v1/tax/(\d+)$').firstMatch(path);
  if (tax != null) body = (fixture['tax']! as Map)[tax.group(1)];
  if (body == null) return http.Response('not found', 404);
  // Bytes, not a string: the demo data contains non-Latin-1 characters.
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

void main() {
  late Map<String, Object?> fixture;

  setUpAll(() async {
    fixture = await ApiEncoding.demoFixture(testNow);
  });

  test('the committed fixture matches the demo data', () async {
    final encoded = '${const JsonEncoder.withIndent('  ').convert(fixture)}\n';
    if (Platform.environment['UPDATE_FIXTURES'] == '1') {
      await _fixtureFile.parent.create(recursive: true);
      await _fixtureFile.writeAsString(encoded);
      return;
    }
    if (!_fixtureFile.existsSync()) {
      markTestSkipped('No fixture yet: run with UPDATE_FIXTURES=1.');
      return;
    }
    expect(
      jsonDecode(await _fixtureFile.readAsString()),
      jsonDecode(encoded),
      reason:
          'server/fixtures/demo.json is out of date. Regenerate it with '
          'UPDATE_FIXTURES=1 flutter test test/contract_test.dart',
    );
  });

  test('the app decodes exactly what the demo produces', () async {
    final remote = RemoteFinancialRepository(
      FinoraApiClient(
        baseUrl: Uri.parse('https://backend.test/'),
        client: _fakeBackend(fixture),
      ),
    );
    final mock = MockFinancialRepository(
      institutionIds: {...InstitutionCatalogue.demoInstitutionIds, 'raiffeisen'},
      products: FinancialProductType.values.toSet(),
      clock: () => testNow,
    );

    final remoteAccounts = await remote.getAccounts();
    final mockAccounts = await mock.getAccounts();
    expect(
      [for (final a in remoteAccounts) (a.id, a.type, a.balance, a.monthlyChange)],
      [for (final a in mockAccounts) (a.id, a.type, a.balance, a.monthlyChange)],
    );
    expect(
      [for (final i in await remote.getInstitutions()) (i.id, i.connectionMethod)],
      [for (final i in await mock.getInstitutions()) (i.id, i.connectionMethod)],
    );

    for (final account in mockAccounts) {
      final expected = await mock.getAccountAnalytics(account.id, historyMonths: 24);
      final actual = await remote.getAccountAnalytics(account.id, historyMonths: 24);
      expect(actual.monthlyIncome, expected.monthlyIncome);
      expect(actual.monthlySpending, expected.monthlySpending);
      expect(
        [for (final p in actual.balanceHistory) (p.month, p.balance)],
        [for (final p in expected.balanceHistory) (p.month, p.balance)],
      );
      expect(
        [for (final b in actual.recurringPayments) (b.merchant, b.amount, b.nextDueAt)],
        [for (final b in expected.recurringPayments) (b.merchant, b.amount, b.nextDueAt)],
      );
    }

    final transactions = await remote.getTransactions();
    expect(transactions.length, (await mock.getTransactions()).length);
    expect(
      await remote.getPillar3aContributions(year: 2026),
      await mock.getPillar3aContributions(year: 2026),
    );
    final tax = await remote.getTaxYearData(2025);
    final expectedTax = await mock.getTaxYearData(2025);
    expect(
      [for (final f in tax.accounts) (f.account.id, f.closingBalance, f.interestPaid)],
      [for (final f in expectedTax.accounts) (f.account.id, f.closingBalance, f.interestPaid)],
    );
  });
}
