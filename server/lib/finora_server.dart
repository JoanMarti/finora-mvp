import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// What the reference backend keeps from the app's write calls. Everything
/// is aggregated or hashed: see docs/api.md.
class InstallationStore {
  final funnels = <String, Map<String, Object?>>{};
  final reminders = <String, Map<String, Object?>>{};
  final devices = <String, Map<String, Object?>>{};
}

/// Accounts for `/v1/auth/*`. In memory: the reference server shows the
/// contract, a production server keeps them in a database and e-mails the
/// codes. The verification code is always [devCode] here.
class AccountRegistry {
  AccountRegistry({Random? random}) : _random = random ?? Random.secure();

  static const devCode = '123456';
  static const maxAttempts = 5;

  final Random _random;
  final users = <String, Map<String, Object?>>{};
  final tokens = <String, String>{};
  final _failures = <String, int>{};

  String _randomId(int bytes) => base64Url
      .encode([for (var i = 0; i < bytes; i++) _random.nextInt(256)])
      .replaceAll('=', '');

  static String hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static bool acceptsPassword(String password, String email) {
    final local = email.split('@').first;
    return password.length >= 10 &&
        RegExp('[A-Za-z]').hasMatch(password) &&
        RegExp(r'\d').hasMatch(password) &&
        !(local.length >= 3 && password.toLowerCase().contains(local));
  }

  Map<String, Object?> publicUser(Map<String, Object?> user) => {
    'id': user['id'],
    'email': user['email'],
    'firstName': user['firstName'],
    'emailVerified': user['verified'],
  };

  String issueToken(String email) {
    final token = _randomId(24);
    tokens[token] = email;
    return token;
  }

  bool lockedOut(String key) => (_failures[key] ?? 0) >= maxAttempts;
  void fail(String key) => _failures[key] = (_failures[key] ?? 0) + 1;
  void clear(String key) => _failures.remove(key);

  Map<String, Object?> create({
    required String email,
    required String firstName,
    required String password,
    required String termsVersion,
    required bool marketing,
  }) {
    final salt = _randomId(12);
    return users[email] = {
      'id': 'usr_${_randomId(9)}',
      'email': email,
      'firstName': firstName,
      'salt': salt,
      'hash': hash(password, salt),
      'verified': false,
      'termsVersion': termsVersion,
      'marketing': marketing,
    };
  }
}

/// Builds the v1 API over [fixtures], a JSON map produced from the app's
/// demo data (`fixtures/demo.json`). When [accessToken] is set, every
/// request must send it as a bearer token.
Handler buildHandler(
  Map<String, Object?> fixtures, {
  InstallationStore? store,
  AccountRegistry? accounts,
  String? accessToken,
  List<Map<String, Object?>> partners = const [],
}) {
  final installations = store ?? InstallationStore();
  final registry = accounts ?? AccountRegistry();
  final router = Router();

  Response reply(Object? body, {int status = 200}) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  Response problem(int status, String message) =>
      reply({'error': message}, status: status);
  // Auth errors carry a machine-readable code the app maps to its texts.
  Response authProblem(int status, String code, String message) =>
      reply({'error': message, 'code': code}, status: status);
  String email(Map<String, Object?> body) =>
      '${body['email'] ?? ''}'.trim().toLowerCase();
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  Map<String, Object?> section(String key) =>
      (fixtures[key] as Map?)?.cast<String, Object?>() ?? const {};

  router
    ..post('/v1/auth/register', (Request request) async {
      final body = await _object(request) ?? const {};
      final address = email(body);
      final password = '${body['password'] ?? ''}';
      final firstName = '${body['firstName'] ?? ''}'.trim();
      if (!emailPattern.hasMatch(address) || firstName.isEmpty) {
        return authProblem(422, 'invalidEmail', 'Name and e-mail are required');
      }
      if (body['termsVersion'] is! String) {
        return problem(422, 'The terms must be accepted');
      }
      if (!AccountRegistry.acceptsPassword(password, address)) {
        return authProblem(422, 'weakPassword', 'Password too weak');
      }
      if (registry.users.containsKey(address)) {
        return authProblem(409, 'emailTaken', 'E-mail already registered');
      }
      final user = registry.create(
        email: address,
        firstName: firstName,
        password: password,
        termsVersion: body['termsVersion']! as String,
        marketing: body['marketing'] == true,
      );
      return reply({'user': registry.publicUser(user)}, status: 201);
    })
    ..post('/v1/auth/verify', (Request request) async {
      final body = await _object(request) ?? const {};
      final address = email(body);
      final key = 'code:$address';
      if (registry.lockedOut(key)) {
        return authProblem(429, 'tooManyAttempts', 'Request a new code');
      }
      final user = registry.users[address];
      if (user == null || body['code'] != AccountRegistry.devCode) {
        registry.fail(key);
        return authProblem(400, 'invalidCode', 'Wrong code');
      }
      registry.clear(key);
      user['verified'] = true;
      return reply({
        'user': registry.publicUser(user),
        'accessToken': registry.issueToken(address),
      });
    })
    ..post('/v1/auth/resend', (Request request) async {
      final body = await _object(request) ?? const {};
      registry.clear('code:${email(body)}');
      return Response(204);
    })
    ..post('/v1/auth/login', (Request request) async {
      final body = await _object(request) ?? const {};
      final address = email(body);
      final key = 'login:$address';
      if (registry.lockedOut(key)) {
        return authProblem(429, 'tooManyAttempts', 'Try again later');
      }
      final user = registry.users[address];
      final password = '${body['password'] ?? ''}';
      if (user == null ||
          AccountRegistry.hash(password, '${user['salt']}') != user['hash']) {
        registry.fail(key);
        return authProblem(401, 'invalidCredentials', 'Wrong e-mail or password');
      }
      registry.clear(key);
      return reply({
        'user': registry.publicUser(user),
        'accessToken': registry.issueToken(address),
      });
    })
    // Same answer whether or not the address exists.
    ..post('/v1/auth/password-reset', (Request _) => Response(204))
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
    // Partner links by offer kind. The reference server has no contracts,
    // so it returns the configured list (empty by default).
    ..get('/v1/partners', (Request _) => reply(partners))
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
    if (accessToken == null || request.url.path.startsWith('v1/auth/')) {
      return inner(request);
    }
    final header = request.headers['authorization'] ?? '';
    final token = header.startsWith('Bearer ') ? header.substring(7) : '';
    if (token != accessToken && !registry.tokens.containsKey(token)) {
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
