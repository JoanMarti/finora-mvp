import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/data/mock_market_data_repository.dart';
import 'package:finora/domain/user_session.dart';
import 'package:flutter_riverpod/misc.dart';

/// Wires the demo data sources into the app. A production build would return
/// bLink/OpenWealth-backed repositories here instead; nothing else changes.
List<Override> demoOverrides({SessionStore? sessionStore}) => [
  if (sessionStore != null) sessionStoreProvider.overrideWithValue(sessionStore),
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
