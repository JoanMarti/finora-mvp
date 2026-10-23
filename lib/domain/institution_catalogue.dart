import 'package:finora/domain/models.dart';

/// Swiss institutions Finora can show. This is the single source of truth for
/// names, brand colours and connection methods across onboarding, connection
/// and account screens.
abstract final class InstitutionCatalogue {
  static const all = <Institution>[
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
