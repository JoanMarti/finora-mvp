import 'package:finora/domain/models.dart';

/// Swiss institutions Finora can show. This is the single source of truth for
/// names, brand colours and connection methods across onboarding, connection
/// and account screens.
abstract final class InstitutionCatalogue {
  /// Shows made-up institutions instead of the real ones. Used for the
  /// store screenshots, so the listing does not suggest an affiliation with
  /// any bank. Ids, products and connection methods stay the same.
  static bool neutralNames = false;

  static List<Institution> get all => neutralNames ? _neutral : _real;

  static const _real = <Institution>[
    Institution(
      id: 'ubs',
      name: 'UBS',
      shortName: 'UBS',
      colorValue: 0xFFE60000,
      connectionMethod: ConnectionMethod.bLink,
      productTypes: {
        FinancialProductType.currentAccount,
        FinancialProductType.savings,
        FinancialProductType.creditCard,
        FinancialProductType.investments,
        FinancialProductType.pillar3a,
      },
    ),
    Institution(
      id: 'zkb',
      name: 'Zürcher Kantonalbank',
      shortName: 'ZKB',
      colorValue: 0xFF1377B8,
      connectionMethod: ConnectionMethod.bLink,
      productTypes: {
        FinancialProductType.currentAccount,
        FinancialProductType.savings,
      },
    ),
    Institution(
      id: 'postfinance',
      name: 'PostFinance',
      shortName: 'PF',
      colorValue: 0xFFB58A00,
      connectionMethod: ConnectionMethod.bLink,
      productTypes: {
        FinancialProductType.currentAccount,
        FinancialProductType.savings,
      },
    ),
    Institution(
      id: 'raiffeisen',
      name: 'Raiffeisen',
      shortName: 'RA',
      colorValue: 0xFF2B2B2B,
      connectionMethod: ConnectionMethod.bLink,
      productTypes: {
        FinancialProductType.currentAccount,
        FinancialProductType.mortgage,
      },
    ),
    Institution(
      id: 'swissquote',
      name: 'Swissquote',
      shortName: 'SQ',
      colorValue: 0xFFEB232B,
      connectionMethod: ConnectionMethod.openWealth,
      productTypes: {FinancialProductType.investments},
    ),
    Institution(
      id: 'julius-baer',
      name: 'Julius Baer',
      shortName: 'JB',
      colorValue: 0xFF0D2240,
      connectionMethod: ConnectionMethod.openWealth,
      productTypes: {FinancialProductType.investments},
    ),
    Institution(
      id: 'pictet',
      name: 'Pictet',
      shortName: 'PI',
      colorValue: 0xFF5B2333,
      connectionMethod: ConnectionMethod.openWealth,
      productTypes: {FinancialProductType.investments},
    ),
    Institution(
      id: 'frankly',
      name: 'frankly',
      shortName: 'fr',
      colorValue: 0xFF111111,
      connectionMethod: ConnectionMethod.manual,
      productTypes: {FinancialProductType.pillar3a},
    ),
    Institution(
      id: 'viac',
      name: 'VIAC',
      shortName: 'VI',
      colorValue: 0xFF1F5C4A,
      connectionMethod: ConnectionMethod.manual,
      productTypes: {FinancialProductType.pillar3a},
    ),
    Institution(
      id: 'finpension',
      name: 'finpension',
      shortName: 'fp',
      colorValue: 0xFF3D3D8F,
      connectionMethod: ConnectionMethod.manual,
      productTypes: {FinancialProductType.pillar3a},
    ),
  ];

  /// Fictional name, short name and colour for each institution.
  static const _neutralLook = <String, (String, String, int)>{
    'ubs': ('Alpenrose Bank', 'AR', 0xFF027DB9),
    'zkb': ('Lakeside Bank', 'LB', 0xFF2E8B57),
    'postfinance': ('Riverside Bank', 'RB', 0xFFB58A00),
    'raiffeisen': ('Valley Cooperative Bank', 'VC', 0xFF6B4E9B),
    'swissquote': ('Summit Invest', 'SI', 0xFFE07A2F),
    'julius-baer': ('Harbour Private Bank', 'HP', 0xFF0D2240),
    'pictet': ('Meridian Wealth', 'MW', 0xFF5B2333),
    'frankly': ('Pinewood 3a', 'PW', 0xFF1F5C4A),
    'viac': ('Cedar 3a', 'CE', 0xFF3D7A5C),
    'finpension': ('Aspen 3a', 'AS', 0xFF3D3D8F),
  };

  static final _neutral = <Institution>[
    for (final institution in _real)
      Institution(
        id: institution.id,
        name: _neutralLook[institution.id]?.$1 ?? institution.name,
        shortName: _neutralLook[institution.id]?.$2 ?? institution.shortName,
        colorValue:
            _neutralLook[institution.id]?.$3 ?? institution.colorValue,
        connectionMethod: institution.connectionMethod,
        productTypes: institution.productTypes,
      ),
  ];

  /// Institutions used when someone skips onboarding with demo data.
  static const demoInstitutionIds = {'ubs', 'zkb', 'swissquote', 'frankly'};

  static Institution? byId(String id) =>
      all.where((institution) => institution.id == id).firstOrNull;

  static String nameOf(String id) => byId(id)?.name ?? id;

  /// Institutions offering at least one of [types], in catalogue order.
  static List<Institution> offering(Set<FinancialProductType> types) => all
      .where((institution) => institution.productTypes.any(types.contains))
      .toList();
}
