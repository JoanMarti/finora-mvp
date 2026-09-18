import 'package:finora/domain/market_data_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketDataRepositoryProvider = Provider<MarketDataRepository>(
  (ref) => MockMarketDataRepository(),
);

final swissMarketThemesProvider = FutureProvider(
  (ref) => ref.watch(marketDataRepositoryProvider).getSwissMarketThemes(),
);

class MockMarketDataRepository implements MarketDataRepository {
  @override
  Future<List<MarketTheme>> getSwissMarketThemes() async => const [
    MarketTheme(
      id: 'swiss-equities',
      type: MarketThemeType.equities,
      title: 'Swiss equity ETFs',
      description: 'Explore broad exposure to established Swiss companies with one product.',
      tag: 'Growth',
    ),
    MarketTheme(
      id: 'chf-bonds',
      type: MarketThemeType.bonds,
      title: 'CHF bond funds',
      description: 'Compare diversified, Swiss-franc income options and their interest-rate risk.',
      tag: 'Income',
    ),
    MarketTheme(
      id: 'pillar-3a',
      type: MarketThemeType.retirement,
      title: 'Pillar 3a portfolios',
      description: 'Review equity allocation, fees and risk across retirement providers.',
      tag: 'Retirement',
    ),
  ];
}
