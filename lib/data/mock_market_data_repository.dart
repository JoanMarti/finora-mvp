import 'package:finora/domain/market_data_repository.dart';

class MockMarketDataRepository implements MarketDataRepository {
  const MockMarketDataRepository();

  @override
  Future<List<MarketTheme>> getSwissMarketThemes() async => const [
    MarketTheme(
      id: 'chf-bonds',
      type: MarketThemeType.bonds,
      title: 'Understand CHF bond funds',
      description:
          'Learn how duration, credit quality and fees affect lower-volatility CHF investments.',
      tag: 'LEARN',
    ),
    MarketTheme(
      id: 'swiss-equities',
      type: MarketThemeType.equities,
      title: 'Compare broad Swiss equity ETFs',
      description:
          'Explore costs, index coverage and concentration before considering any product.',
      tag: 'EXPLORE',
    ),
    MarketTheme(
      id: 'pillar-3a',
      type: MarketThemeType.retirement,
      title: 'Compare Pillar 3a portfolios',
      description:
          'Review equity allocation, fees and risk across retirement providers.',
      tag: 'RETIREMENT',
    ),
  ];
}
