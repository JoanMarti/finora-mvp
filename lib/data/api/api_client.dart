import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A failed call to the Finora backend.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  /// HTTP status, or `0` when the server could not be reached.
  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin JSON client for the Finora backend-for-frontend (see
/// `docs/api.md`). The backend talks to bLink and OpenWealth; the app never
/// sees bank credentials.
class FinoraApiClient {
  FinoraApiClient({
    required this.baseUrl,
    required this.client,
    Future<String?> Function()? accessToken,
    this.timeout = const Duration(seconds: 15),
  }) : _accessToken = accessToken ?? _noToken;

  static Future<String?> _noToken() async => null;

  final Uri baseUrl;
  final http.Client client;
  final Future<String?> Function() _accessToken;
  final Duration timeout;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.path.endsWith('/') ? baseUrl.path : '${baseUrl.path}/';
    final relative = path.startsWith('/') ? path.substring(1) : path;
    return baseUrl.replace(
      path: '$base$relative',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _accessToken();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send(() async => client.get(_uri(path, query), headers: await _headers()));

  Future<Object?> post(String path, [Object? body]) => _send(
    () async => client.post(
      _uri(path),
      headers: await _headers(json: true),
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<Object?> put(String path, Object? body) => _send(
    () async => client.put(
      _uri(path),
      headers: await _headers(json: true),
      body: jsonEncode(body),
    ),
  );

  Future<Object?> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, 'The server did not answer in time.');
    } on http.ClientException catch (error) {
      throw ApiException(0, error.message);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(response.statusCode, 'Invalid JSON in response.');
    }
  }
}
