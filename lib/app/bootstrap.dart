import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/data/mock_market_data_repository.dart';
import 'package:finora/domain/user_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wires the demo data sources into the app. A production build would return
/// bLink/OpenWealth-backed repositories here instead; nothing else changes.
List<Override> demoOverrides({SessionStore? sessionStore}) => [
  if (sessionStore != null) sessionStoreProvider.overrideWithValue(sessionStore),
  financialRepositoryProvider.overrideWith((ref) {
    final session = ref.watch(sessionProvider);
    return MockFinancialRepository(
      institutionIds: session.connectedInstitutionIds,
      products: session.products,
      clock: ref.watch(clockProvider),
    );
  }),
  marketDataRepositoryProvider.overrideWithValue(
    const MockMarketDataRepository(),
  ),
];
