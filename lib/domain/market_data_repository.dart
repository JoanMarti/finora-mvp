enum MarketThemeType { equities, bonds, retirement }

class MarketTheme {
  const MarketTheme({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.tag,
  });

  final String id;
  final MarketThemeType type;
  final String title;
  final String description;
  final String tag;
}

abstract class MarketDataRepository {
  Future<List<MarketTheme>> getSwissMarketThemes();
}
