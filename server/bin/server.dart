import 'dart:convert';
import 'dart:io';

import 'package:finora_server/finora_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Runs the reference backend:
///
///     dart run bin/server.dart
///
/// `PORT` (default 8080) and `FINORA_API_TOKEN` (optional bearer token)
/// come from the environment. The app then runs with
/// `--dart-define=FINORA_API_URL=http://localhost:8080/`.
Future<void> main() async {
  final fixtures = jsonDecode(
    await File.fromUri(
      Platform.script.resolve('../fixtures/demo.json'),
    ).readAsString(),
  ) as Map<String, Object?>;
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(
        buildHandler(
          fixtures,
          accessToken: Platform.environment['FINORA_API_TOKEN'],
        ),
      );
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Finora reference backend on http://localhost:${server.port}/');
}
