import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// What the reference backend keeps from the app's write calls. Everything
/// is aggregated or hashed: see docs/api.md.
class InstallationStore {
  final funnels = <String, Map<String, Object?>>{};
  final reminders = <String, Map<String, Object?>>{};
  final devices = <String, Map<String, Object?>>{};
}

/// Builds the v1 API over [fixtures], a JSON map produced from the app's
/// demo data (`fixtures/demo.json`). When [accessToken] is set, every
/// request must send it as a bearer token.
Handler buildHandler(
  Map<String, Object?> fixtures, {
  InstallationStore? store,
  String? accessToken,
}) {
  final installations = store ?? InstallationStore();
  final router = Router();

  Response reply(Object? body, {int status = 200}) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  Response problem(int status, String message) =>
      reply({'error': message}, status: status);

  Map<String, Object?> section(String key) =>
      (fixtures[key] as Map?)?.cast<String, Object?>() ?? const {};

  router
    ..get('/v1/institutions', (Request _) => reply(fixtures['institutions']))
    ..get('/v1/connections', (Request _) => reply(fixtures['connections']))
    ..get('/v1/accounts', (Request _) => reply(fixtures['accounts']))
    ..get('/v1/accounts/<id>/analytics', (Request request, String id) {
      final analytics = (section('analytics')[id] as Map?)
          ?.cast<String, Object?>();
      if (analytics == null) return problem(404, 'Unknown account');
      final months =
          int.tryParse(request.url.queryParameters['months'] ?? '') ?? 6;
      if (months < 1 || months > 24) {
        return problem(400, 'months must be between 1 and 24');
      }
      final history = (analytics['balanceHistory'] as List?) ?? const [];
      return reply({
        ...analytics,
        'balanceHistory': history.length <= months
            ? history
            : history.sublist(history.length - months),
      });
    })
    ..get('/v1/transactions', (Request request) {
      final accountId = request.url.queryParameters['accountId'];
      final all = (fixtures['transactions'] as List?) ?? const [];
      return reply([
        for (final item in all)
          if (accountId == null || (item as Map)['accountId'] == accountId)
            item,
      ]);
    })
    ..get('/v1/pillar3a/contributions', (Request request) {
      final year = request.url.queryParameters['year'];
      final amount = section('pillar3aContributions')[year];
      if (amount == null) return problem(404, 'No data for that year');
      return reply({'amount': amount});
    })
    ..get('/v1/tax/<year>', (Request _, String year) {
      final data = section('tax')[year];
      if (data == null) return problem(404, 'No data for that year');
      return reply(data);
    })
    ..post('/v1/refresh', (Request _) => Response(204))
    ..put('/v1/installations/<id>/funnel', (Request request, String id) async {
      final body = await _object(request);
      // Privacy guard: only aggregated fields are accepted.
      const allowed = {'counts', 'pursuedSavingLow', 'pursuedSavingHigh'};
      if (body == null || !allowed.containsAll(body.keys)) {
        return problem(422, 'Only aggregated funnel fields are accepted');
      }
      installations.funnels[id] = body;
      return Response(204);
    })
    ..put('/v1/installations/<id>/reminders', (
      Request request,
      String id,
    ) async {
      final body = await _object(request);
      final items = body?['reminders'];
      if (body == null || items is! List) {
        return problem(422, 'Expected {language, reminders: [...]}');
      }
      for (final item in items) {
        if (item is! Map ||
            !{'id', 'kind', 'date'}.containsAll(item.keys.cast<String>())) {
          return problem(422, 'Reminders carry only id, kind and date');
        }
      }
      installations.reminders[id] = body;
      return Response(204);
    })
    ..put('/v1/installations/<id>/device', (Request request, String id) async {
      final body = await _object(request);
      if (body == null || body['pushToken'] is! String) {
        return problem(422, 'Expected {platform, pushToken}');
      }
      installations.devices[id] = body;
      return Response(204);
    })
    ..post('/v1/purchases/verify', (Request request) async {
      final body = await _object(request);
      if (body == null || body['receipt'] is! String) {
        return problem(422, 'Expected {platform, receipt}');
      }
      // The reference server has no store credentials: nothing is active.
      return reply({'active': false, 'since': null, 'expiresAt': null});
    });

  Middleware auth() => (inner) => (request) {
    if (accessToken == null) return inner(request);
    final header = request.headers['authorization'];
    if (header != 'Bearer $accessToken') {
      return problem(401, 'Sign in again');
    }
    return inner(request);
  };

  return const Pipeline().addMiddleware(auth()).addHandler(router.call);
}

Future<Map<String, Object?>?> _object(Request request) async {
  try {
    final decoded = jsonDecode(await request.readAsString());
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}
