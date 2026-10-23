import 'package:finora/domain/market_data_repository.dart';

/// Illustrative, educational themes. A real provider would return content
/// already translated on the server.
class MockMarketDataRepository implements MarketDataRepository {
  const MockMarketDataRepository();

  @override
  Future<List<MarketTheme>> getSwissMarketThemes({
    required String languageCode,
  }) async {
    final copy = _copy[languageCode] ?? _copy['en']!;
    return [
      for (final (id, type) in _themes)
        MarketTheme(
          id: id,
          type: type,
          tag: copy[id]![0],
          title: copy[id]![1],
          description: copy[id]![2],
        ),
    ];
  }

  static const _themes = [
    ('chf-bonds', MarketThemeType.bonds),
    ('swiss-equities', MarketThemeType.equities),
    ('pillar-3a', MarketThemeType.retirement),
  ];

  /// Theme id → [tag, title, description] per language.
  static const _copy = <String, Map<String, List<String>>>{
    'en': {
      'chf-bonds': [
        'LEARN',
        'Understand CHF bond funds',
        'Learn how duration, credit quality and fees affect lower-volatility CHF investments.',
      ],
      'swiss-equities': [
        'EXPLORE',
        'Compare broad Swiss equity ETFs',
        'Explore costs, index coverage and concentration before considering any product.',
      ],
      'pillar-3a': [
        'RETIREMENT',
        'Compare Pillar 3a portfolios',
        'Review equity allocation, fees and risk across retirement providers.',
      ],
    },
    'de': {
      'chf-bonds': [
        'LERNEN',
        'CHF-Obligationenfonds verstehen',
        'Erfahren Sie, wie Duration, Bonität und Gebühren schwankungsärmere CHF-Anlagen beeinflussen.',
      ],
      'swiss-equities': [
        'ENTDECKEN',
        'Breite Schweizer Aktien-ETFs vergleichen',
        'Prüfen Sie Kosten, Indexabdeckung und Konzentration, bevor Sie ein Produkt in Betracht ziehen.',
      ],
      'pillar-3a': [
        'VORSORGE',
        'Säule-3a-Portfolios vergleichen',
        'Vergleichen Sie Aktienanteil, Gebühren und Risiko verschiedener Vorsorgeanbieter.',
      ],
    },
    'fr': {
      'chf-bonds': [
        'APPRENDRE',
        'Comprendre les fonds obligataires en CHF',
        'Découvrez comment la duration, la qualité de crédit et les frais influencent les placements en CHF moins volatils.',
      ],
      'swiss-equities': [
        'EXPLORER',
        'Comparer les ETF d’actions suisses diversifiés',
        'Examinez les coûts, la couverture de l’indice et la concentration avant d’envisager un produit.',
      ],
      'pillar-3a': [
        'PRÉVOYANCE',
        'Comparer les portefeuilles du pilier 3a',
        'Comparez la part d’actions, les frais et le risque des différents prestataires de prévoyance.',
      ],
    },
    'it': {
      'chf-bonds': [
        'IMPARARE',
        'Capire i fondi obbligazionari in CHF',
        'Scopri come duration, qualità del credito e commissioni influenzano gli investimenti in CHF meno volatili.',
      ],
      'swiss-equities': [
        'ESPLORARE',
        'Confrontare ETF azionari svizzeri diversificati',
        'Valuta costi, copertura dell’indice e concentrazione prima di considerare un prodotto.',
      ],
      'pillar-3a': [
        'PREVIDENZA',
        'Confrontare i portafogli del pilastro 3a',
        'Confronta quota azionaria, commissioni e rischio dei diversi fornitori di previdenza.',
      ],
    },
  };
}
