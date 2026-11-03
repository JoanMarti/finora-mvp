import 'package:finora/domain/models.dart';

/// Guesses categories for bookings read from a statement, from well-known
/// Swiss merchants and keywords in the booking text.
abstract final class MerchantCategories {
  static const _healthInsurers = [
    'css', 'helsana', 'swica', 'sanitas', 'visana', 'concordia', 'kpt',
    'assura', 'groupe mutuel', 'sympany', 'atupri', 'ökk', 'oekk', 'egk',
    'krankenkasse', 'caisse maladie', 'cassa malati',
  ];
  static const _householdInsurers = [
    'axa', 'mobiliar', 'mobilière', 'mobiliere', 'zurich versicherung',
    'allianz', 'generali', 'helvetia', 'baloise', 'vaudoise', 'smile.direct',
  ];
  static const _telecom = [
    'swisscom', 'sunrise', 'salt mobile', 'salt.ch', 'wingo', 'yallo',
    'upc', 'quickline', 'init7', 'galaxus mobile', 'm-budget mobile',
  ];
  static const _streaming = [
    'netflix', 'spotify', 'disney', 'apple music', 'youtube', 'dazn',
    'sky show', 'blue+', 'teleclub', 'audible', 'prime video',
  ];
  static const _memberships = [
    'fitness', 'puregym', 'kieser', 'injoy', 'activ fitness', 'gym',
  ];
  static const _electricity = [
    'ewz', 'bkw', 'ckw', 'groupe e', 'romande energie', 'axpo', 'iwb',
    'services industriels', 'elektrizitätswerk', 'energie',
  ];
  static const _radioTv = ['serafe'];

  static const _keywords = <TransactionCategory, List<String>>{
    TransactionCategory.housing: [
      'miete', 'mietzins', 'loyer', 'affitto', 'rent', 'hypothek',
      'hypothèque', 'liegenschaft', 'verwaltung', 'régie', 'regie',
      'immobilien',
    ],
    TransactionCategory.groceries: [
      'migros', 'coop', 'denner', 'aldi', 'lidl', 'volg', 'spar', 'landi',
      'aligro', 'alnatura', 'globus', 'manor food',
    ],
    TransactionCategory.transport: [
      'sbb', 'cff', 'ffs', 'zvv', 'bls', 'tpg', 'vbz', 'postauto',
      'carpostal', 'uber', 'mobility', 'shell', 'avia', 'socar', 'tamoil',
      'migrol', 'agrola', 'parking', 'parkhaus', 'easypark', 'twint parking',
    ],
    TransactionCategory.insurance: [
      ..._healthInsurers, ..._householdInsurers, 'versicherung',
      'assurance', 'assicurazione', 'tcs',
    ],
    TransactionCategory.utilities: [
      ..._telecom, ..._electricity, ..._radioTv, 'strom', 'wasserwerk',
    ],
    TransactionCategory.dining: [
      'restaurant', 'ristorante', 'café', 'cafe', 'bar ', 'pizzeria',
      'mcdonald', 'burger king', 'starbucks', 'sushi', 'takeaway',
      'eat.ch', 'just eat', 'uber eats', 'smood', 'kebab', 'bistro',
    ],
    TransactionCategory.shopping: [
      'zalando', 'galaxus', 'digitec', 'brack', 'ikea', 'h&m', 'zara',
      'manor', 'interdiscount', 'mediamarkt', 'media markt', 'fust',
      'decathlon', 'ochsner', 'amazon', 'aliexpress', 'temu', 'apple.com',
      'jumbo', 'hornbach', 'bauhaus', 'ex libris', 'orell füssli',
      ..._streaming,
    ],
  };

  static bool _has(String text, List<String> keys) {
    final lower = ' ${text.toLowerCase()} ';
    return keys.any(
      (key) => RegExp(
        '(^|[^a-zà-ÿ])${RegExp.escape(key)}([^a-zà-ÿ]|\$)',
      ).hasMatch(lower),
    );
  }

  /// Money coming in is income; spending follows the first matching
  /// keyword list, else "other".
  static TransactionCategory categorize(String text, Money amount) {
    if (!amount.isNegative) return TransactionCategory.income;
    for (final entry in _keywords.entries) {
      if (_has(text, entry.value)) return entry.key;
    }
    return TransactionCategory.other;
  }

  /// The kind of bill a recurring payment is, or `null` when it is not one
  /// Finora tracks (rent, for instance).
  static BillCategory? billCategory(String text) {
    if (_has(text, _healthInsurers)) return BillCategory.healthInsurance;
    if (_has(text, _householdInsurers)) return BillCategory.householdInsurance;
    if (_has(text, _telecom)) return BillCategory.phoneInternet;
    if (_has(text, _streaming)) return BillCategory.streaming;
    if (_has(text, _memberships)) return BillCategory.membership;
    if (_has(text, _radioTv)) return BillCategory.radioTvFee;
    if (_has(text, _electricity)) return BillCategory.electricity;
    return null;
  }

  /// A short merchant name from a booking text: no reference numbers,
  /// card numbers or dates, at most 40 characters.
  static String merchantName(String text) {
    var name = text
        .replaceAll(RegExp(r'\b\d{2}[./]\d{2}[./]\d{2,4}\b'), ' ')
        .replaceAll(RegExp(r'\b[\dX*]{4,}\b'), ' ')
        .replaceAll(
          RegExp(
            r'^(einkauf|zahlung|e-banking|debitkarte|kartenzahlung|'
            r'achat|paiement|pagamento|acquisto|card payment|twint)\s*:?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty) name = text.trim();
    return name.length > 40 ? '${name.substring(0, 40).trimRight()}…' : name;
  }
}
