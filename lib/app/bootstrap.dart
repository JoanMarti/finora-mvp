import 'package:finora/application/auth.dart';
import 'package:finora/application/backend.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/data/api/api_client.dart';
import 'package:finora/data/api/http_auth_service.dart';
import 'package:finora/data/api/http_backend_services.dart';
import 'package:finora/data/demo_auth_service.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/data/mock_market_data_repository.dart';
import 'package:finora/data/remote_financial_repository.dart';
import 'package:finora/domain/user_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;

/// Backend base URL, e.g. `--dart-define=FINORA_API_URL=https://api.finora.ch/`.
/// Empty (the default) runs the demo with generated data.
const finoraApiUrl = String.fromEnvironment('FINORA_API_URL');

/// The data sources for this build: the backend when [finoraApiUrl] is set,
/// otherwise the demo.
List<Override> appOverrides({
  required SessionStore sessionStore,
  AccountStore? accountStore,
}) {
  if (finoraApiUrl.isEmpty) {
    return demoOverrides(
      sessionStore: sessionStore,
      accountStore: accountStore,
    );
  }
  final tokens = AuthTokenHolder();
  return backendOverrides(
    FinoraApiClient(
      baseUrl: Uri.parse(finoraApiUrl),
      client: http.Client(),
      accessToken: tokens.read,
    ),
    sessionStore: sessionStore,
    tokens: tokens,
  );
}

/// Wires the Finora backend. Signing in stores the access token in
/// [tokens], which the API client sends with every request.
List<Override> backendOverrides(
  FinoraApiClient api, {
  SessionStore? sessionStore,
  AuthTokenHolder? tokens,
}) {
  final services = HttpBackendServices(api);
  return [
    authServiceProvider.overrideWithValue(
      HttpAuthService(api, tokens ?? AuthTokenHolder()),
    ),
    if (sessionStore != null)
      sessionStoreProvider.overrideWithValue(sessionStore),
    financialRepositoryProvider.overrideWith((ref) {
      // Reload when the user connects or removes an institution.
      ref.watch(
        sessionProvider.select((session) => session.connectedInstitutionIds),
      );
      return RemoteFinancialRepository(api);
    }),
    // Market themes are static educational content shipped with the app.
    marketDataRepositoryProvider.overrideWithValue(
      const MockMarketDataRepository(),
    ),
    backendEnabledProvider.overrideWithValue(true),
    funnelReporterProvider.overrideWithValue(services),
    reminderServiceProvider.overrideWithValue(services),
    partnerDirectoryProvider.overrideWithValue(services),
  ];
}

/// Wires the demo data sources into the app. A production build would return
/// bLink/OpenWealth-backed repositories here instead; nothing else changes.
List<Override> demoOverrides({
  SessionStore? sessionStore,
  AccountStore? accountStore,
}) => [
  if (sessionStore != null) sessionStoreProvider.overrideWithValue(sessionStore),
  if (accountStore != null) accountStoreProvider.overrideWithValue(accountStore),
  financialRepositoryProvider.overrideWith((ref) {
    // Only the connected institutions and products shape the data; other
    // session changes (language, goals, consent) must not reload it.
    final (institutionIds, products) = ref.watch(
      sessionProvider.select(
        (session) => (session.connectedInstitutionIds, session.products),
      ),
    );
    return MockFinancialRepository(
      institutionIds: institutionIds,
      products: products,
      clock: ref.watch(clockProvider),
    );
  }),
  marketDataRepositoryProvider.overrideWithValue(
    const MockMarketDataRepository(),
  ),
];
