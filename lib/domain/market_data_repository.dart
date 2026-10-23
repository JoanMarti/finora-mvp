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

abstract interface class MarketDataRepository {
  /// Educational themes in the user's language ([languageCode] such as
  /// `de`). Providers should fall back to English.
  Future<List<MarketTheme>> getSwissMarketThemes({required String languageCode});
}
