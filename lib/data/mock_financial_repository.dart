import 'dart:math' as math;

import 'package:finora/domain/financial_repository.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';

/// Demo data source. It generates a consistent, fictional financial picture
/// for exactly the institutions and products the user selected, with dates
/// relative to "now" so the demo never looks out of date.
class MockFinancialRepository implements FinancialRepository {
  MockFinancialRepository({
    required this.institutionIds,
    this.products = const {},
    this.clock = DateTime.now,
  });

  /// Institutions the user connected.
  final Set<String> institutionIds;

  /// Products chosen in onboarding; empty means "show everything".
  final Set<FinancialProductType> products;
  final DateTime Function() clock;
  DateTime? _refreshedAt;

  /// Monthly Pillar 3a standing order used by the demo profile.
  static const _pillar3aMonthlyContribution = Money.cents(60500);
  static const _pillar3aAnnualLimit = Money.cents(725800);

  DateTime get _now => clock();

  List<_AccountTemplate> get _activeTemplates => _accountTemplates
      .where(
        (template) =>
            institutionIds.contains(template.institutionId) &&
            (products.isEmpty || products.contains(template.type)),
      )
      .toList();

  @override
  Future<List<Institution>> getInstitutions() async => InstitutionCatalogue.all
      .where((institution) => institutionIds.contains(institution.id))
      .toList();

  @override
  Future<List<InstitutionConnection>> getConnections() async {
    final now = _now;
    final refreshedAt = _refreshedAt;
    final institutions = await getInstitutions();
    return [
      for (final institution in institutions)
        if (institution.isManual)
          InstitutionConnection(
            institutionId: institution.id,
            status: ConnectionStatus.manual,
            lastSyncedAt: now.subtract(const Duration(days: 3)),
          )
        else if (refreshedAt != null)
          InstitutionConnection(
            institutionId: institution.id,
            status: ConnectionStatus.connected,
            lastSyncedAt: refreshedAt,
          )
        else if (institution.id == 'zkb')
          // One stale connection keeps the data-health states visible.
          InstitutionConnection(
            institutionId: institution.id,
            status: ConnectionStatus.stale,
            lastSyncedAt: now.subtract(const Duration(hours: 26)),
          )
        else
          InstitutionConnection(
            institutionId: institution.id,
            status: ConnectionStatus.connected,
            lastSyncedAt: now.subtract(
              Duration(minutes: 4 + institution.id.length),
            ),
          ),
    ];
  }

  @override
  Future<List<FinancialAccount>> getAccounts() async => [
    for (final template in _activeTemplates) template.toAccount(),
  ];

  @override
  Future<AccountAnalytics> getAccountAnalytics(
    String accountId, {
    int historyMonths = 6,
  }) async {
    final template = _activeTemplates
        .where((item) => item.id == accountId)
        .firstOrNull;
    if (template == null) return const AccountAnalytics.empty();

    final history = _balanceHistory(template, historyMonths);
    return switch (template.activity) {
      _Activity.salary => _salaryAnalytics(history),
      _Activity.household => _householdAnalytics(history),
      _Activity.card => _cardAnalytics(history),
      _Activity.none => AccountAnalytics(
        monthlyIncome: Money.zero,
        monthlySpending: Money.zero,
        balanceHistory: history,
        cashFlowHistory: const [],
        recurringPayments: const [],
        spendingCategories: const [],
      ),
    };
  }

  @override
  Future<List<FinancialTransaction>> getTransactions({
    String? accountId,
  }) async {
    final accountIds = _activeTemplates.map((template) => template.id).toSet();
    final now = _now;
    final items = <FinancialTransaction>[
      for (final template in _transactionTemplates)
        if (accountIds.contains(template.accountId) &&
            (accountId == null || template.accountId == accountId))
          FinancialTransaction(
            id: template.id,
            accountId: template.accountId,
            merchant: template.merchant,
            category: template.category,
            bookedAt: now.subtract(Duration(days: template.daysAgo)),
            amount: Money.cents(template.cents),
            foreignCurrency: template.foreignCurrency,
          ),
    ];
    items.sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
    return items;
  }

  @override
  Future<Money> getPillar3aContributions({required int year}) async {
    final hasPillar3a = _activeTemplates.any(
      (template) => template.type == FinancialProductType.pillar3a,
    );
    if (!hasPillar3a) return Money.zero;
    final now = _now;
    final months = year < now.year ? 12 : (year == now.year ? now.month : 0);
    final contributed = _pillar3aMonthlyContribution * months;
    return contributed.compareTo(_pillar3aAnnualLimit) > 0
        ? _pillar3aAnnualLimit
        : contributed;
  }

  @override
  Future<TaxYearData> getTaxYearData(int year) async {
    final now = _now;
    final isComplete = year < now.year;
    // Months between 31 December of [year] and today, used to roll the
    // current balance back to the year end with the monthly trend.
    final monthsSinceYearEnd = isComplete
        ? (now.year - year - 1) * 12 + now.month
        : 0;
    final accounts = await getAccounts();
    return TaxYearData(
      year: year,
      asOf: isComplete ? DateTime(year, 12, 31) : now,
      isComplete: isComplete,
      pillar3aContributions: await getPillar3aContributions(year: year),
      accounts: [
        for (final account in accounts)
          _taxFigures(account, monthsSinceYearEnd, isComplete ? 12 : now.month),
      ],
    );
  }

  /// Demo yields: 0.5 % on savings, 1.8 % dividends on securities and
  /// 1.6 % mortgage interest, pro rata for an incomplete year.
  TaxAccountFigures _taxFigures(
    FinancialAccount account,
    int monthsSinceYearEnd,
    int monthsInYear,
  ) {
    final closing =
        account.balance - account.monthlyChange * monthsSinceYearEnd;
    final share = monthsInYear / 12;
    return TaxAccountFigures(
      account: account,
      closingBalance: closing,
      income: switch (account.type) {
        FinancialProductType.savings => closing * (.005 * share),
        FinancialProductType.investments => closing * (.018 * share),
        _ => Money.zero,
      },
      interestPaid: account.type == FinancialProductType.mortgage
          ? closing.abs() * (.016 * share)
          : Money.zero,
    );
  }

  @override
  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _refreshedAt = _now;
  }

  // ---------------------------------------------------------------------------
  // Generated history and analytics
  // ---------------------------------------------------------------------------

  /// First day of the month, [monthsAgo] months before now.
  DateTime _monthStart(int monthsAgo) {
    final now = _now;
    return DateTime(now.year, now.month - monthsAgo);
  }

  List<BalanceHistoryPoint> _balanceHistory(
    _AccountTemplate template,
    int months,
  ) {
    final seed = template.id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final step = template.monthlyChangeCents;
    final wiggleUnit = math.max(step.abs(), template.balanceCents.abs() ~/ 200);
    return [
      for (var monthsAgo = months - 1; monthsAgo >= 0; monthsAgo--)
        BalanceHistoryPoint(
          month: _monthStart(monthsAgo),
          balance: Money.cents(
            monthsAgo == 0
                ? template.balanceCents
                : template.balanceCents -
                      step * monthsAgo +
                      ((((monthsAgo * 37 + seed) % 7) - 3) * wiggleUnit) ~/ 6,
          ),
        ),
    ];
  }

  List<CashFlowPoint> _cashFlow(List<int> income, List<int> spending) => [
    for (var index = 0; index < income.length; index++)
      CashFlowPoint(
        month: _monthStart(income.length - 1 - index),
        income: Money.cents(income[index]),
        spending: Money.cents(spending[index]),
      ),
  ];

  DateTime _dueIn(int days) => _now.add(Duration(days: days));

  AccountAnalytics _salaryAnalytics(List<BalanceHistoryPoint> history) {
    return AccountAnalytics(
      monthlyIncome: const Money.cents(685000),
      monthlySpending: const Money.cents(412800),
      balanceHistory: history,
      cashFlowHistory: _cashFlow(
        const [685000, 685000, 714000, 685000, 685000, 685000],
        const [436000, 512000, 469000, 532000, 448000, 412800],
      ),
      recurringPayments: [
        RecurringPayment(
          merchant: 'CSS Insurance',
          category: BillCategory.healthInsurance,
          amount: const Money.cents(-34820),
          cadence: BillCadence.monthly,
          nextDueAt: _dueIn(5),
        ),
        RecurringPayment(
          merchant: 'AXA',
          category: BillCategory.householdInsurance,
          amount: const Money.cents(-7240),
          cadence: BillCadence.monthlyEquivalent,
          nextDueAt: _dueIn(9),
        ),
        RecurringPayment(
          merchant: 'Swisscom',
          category: BillCategory.phoneInternet,
          amount: const Money.cents(-8990),
          cadence: BillCadence.monthly,
          nextDueAt: _dueIn(11),
        ),
        RecurringPayment(
          merchant: 'PureGym',
          category: BillCategory.membership,
          amount: const Money.cents(-5490),
          cadence: BillCadence.monthly,
          nextDueAt: _dueIn(14),
        ),
        RecurringPayment(
          merchant: 'Netflix',
          category: BillCategory.streaming,
          amount: const Money.cents(-2490),
          cadence: BillCadence.monthly,
          nextDueAt: _dueIn(18),
        ),
      ],
      spendingCategories: const [
        SpendingCategory(
          category: TransactionCategory.housing,
          amount: Money.cents(145000),
          colorValue: 0xFF3C94FF,
        ),
        SpendingCategory(
          category: TransactionCategory.groceries,
          amount: Money.cents(74000),
          colorValue: 0xFF272829,
        ),
        SpendingCategory(
          category: TransactionCategory.utilities,
          amount: Money.cents(67240),
          colorValue: 0xFF7C8182,
        ),
        SpendingCategory(
          category: TransactionCategory.shopping,
          amount: Money.cents(46500),
          colorValue: 0xFF78B6FF,
        ),
        SpendingCategory(
          category: TransactionCategory.insurance,
          amount: Money.cents(42060),
          colorValue: 0xFFA2AAAC,
        ),
        SpendingCategory(
          category: TransactionCategory.transport,
          amount: Money.cents(38000),
          colorValue: 0xFFC2CACC,
        ),
      ],
    );
  }

  AccountAnalytics _householdAnalytics(List<BalanceHistoryPoint> history) {
    return AccountAnalytics(
      monthlyIncome: const Money.cents(250000),
      monthlySpending: const Money.cents(229800),
      balanceHistory: history,
      cashFlowHistory: _cashFlow(
        const [250000, 250000, 250000, 250000, 250000, 250000],
        const [231000, 244500, 226000, 238800, 241200, 229800],
      ),
      recurringPayments: [
        RecurringPayment(
          merchant: 'EWZ',
          category: BillCategory.electricity,
          amount: const Money.cents(-6400),
          cadence: BillCadence.monthly,
          nextDueAt: _dueIn(8),
        ),
        RecurringPayment(
          merchant: 'Serafe',
          category: BillCategory.radioTvFee,
          amount: const Money.cents(-2790),
          cadence: BillCadence.monthlyEquivalent,
          nextDueAt: _dueIn(20),
        ),
      ],
      spendingCategories: const [
        SpendingCategory(
          category: TransactionCategory.groceries,
          amount: Money.cents(98000),
          colorValue: 0xFF272829,
        ),
        SpendingCategory(
          category: TransactionCategory.dining,
          amount: Money.cents(61500),
          colorValue: 0xFF3C94FF,
        ),
        SpendingCategory(
          category: TransactionCategory.utilities,
          amount: Money.cents(39100),
          colorValue: 0xFF7C8182,
        ),
        SpendingCategory(
          category: TransactionCategory.other,
          amount: Money.cents(31200),
          colorValue: 0xFFC2CACC,
        ),
      ],
    );
  }

  AccountAnalytics _cardAnalytics(List<BalanceHistoryPoint> history) {
    return AccountAnalytics(
      monthlyIncome: Money.zero,
      monthlySpending: const Money.cents(184550),
      balanceHistory: history,
      cashFlowHistory: const [],
      recurringPayments: [
        RecurringPayment(
          merchant: 'Spotify',
          category: BillCategory.streaming,
          amount: const Money.cents(-1295),
          cadence: BillCadence.monthly,
          nextDueAt: _dueIn(6),
        ),
      ],
      spendingCategories: const [
        SpendingCategory(
          category: TransactionCategory.shopping,
          amount: Money.cents(96400),
          colorValue: 0xFF78B6FF,
        ),
        SpendingCategory(
          category: TransactionCategory.dining,
          amount: Money.cents(52150),
          colorValue: 0xFF3C94FF,
        ),
        SpendingCategory(
          category: TransactionCategory.transport,
          amount: Money.cents(36000),
          colorValue: 0xFFC2CACC,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Demo catalogue of accounts and transactions
// -----------------------------------------------------------------------------

enum _Activity { none, salary, household, card }

class _AccountTemplate {
  const _AccountTemplate({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.type,
    required this.balanceCents,
    required this.maskedIdentifier,
    required this.monthlyChangeCents,
    this.activity = _Activity.none,
  });

  final String id;
  final String institutionId;
  final String name;
  final FinancialProductType type;
  final int balanceCents;
  final String maskedIdentifier;
  final int monthlyChangeCents;
  final _Activity activity;

  FinancialAccount toAccount() => FinancialAccount(
    id: id,
    institutionId: institutionId,
    name: name,
    type: type,
    balance: Money.cents(balanceCents),
    maskedIdentifier: maskedIdentifier,
    monthlyChange: Money.cents(monthlyChangeCents),
  );
}

const _accountTemplates = <_AccountTemplate>[
  _AccountTemplate(
    id: 'ubs-personal',
    institutionId: 'ubs',
    name: 'Personal account',
    type: FinancialProductType.currentAccount,
    balanceCents: 842035,
    maskedIdentifier: '•••• 8472',
    monthlyChangeCents: 90000,
    activity: _Activity.salary,
  ),
  _AccountTemplate(
    id: 'ubs-savings',
    institutionId: 'ubs',
    name: 'Savings',
    type: FinancialProductType.savings,
    balanceCents: 2000000,
    maskedIdentifier: '•••• 1209',
    monthlyChangeCents: 30000,
  ),
  _AccountTemplate(
    id: 'ubs-card',
    institutionId: 'ubs',
    name: 'Visa Platinum',
    type: FinancialProductType.creditCard,
    balanceCents: -184550,
    maskedIdentifier: '•••• 5531',
    monthlyChangeCents: -21040,
    activity: _Activity.card,
  ),
  _AccountTemplate(
    id: 'ubs-invest',
    institutionId: 'ubs',
    name: 'Manage portfolio',
    type: FinancialProductType.investments,
    balanceCents: 1560000,
    maskedIdentifier: 'Mandate 2210',
    monthlyChangeCents: 41200,
  ),
  _AccountTemplate(
    id: 'ubs-3a',
    institutionId: 'ubs',
    name: 'Vitainvest 3a',
    type: FinancialProductType.pillar3a,
    balanceCents: 1520000,
    maskedIdentifier: '3a •••• 0918',
    monthlyChangeCents: 24300,
  ),
  _AccountTemplate(
    id: 'zkb-private',
    institutionId: 'zkb',
    name: 'Private account',
    type: FinancialProductType.currentAccount,
    balanceCents: 1640005,
    maskedIdentifier: '•••• 3601',
    monthlyChangeCents: -48240,
    activity: _Activity.household,
  ),
  _AccountTemplate(
    id: 'zkb-savings',
    institutionId: 'zkb',
    name: 'Savings plus',
    type: FinancialProductType.savings,
    balanceCents: 850000,
    maskedIdentifier: '•••• 7745',
    monthlyChangeCents: 20000,
  ),
  _AccountTemplate(
    id: 'postfinance-private',
    institutionId: 'postfinance',
    name: 'Private account',
    type: FinancialProductType.currentAccount,
    balanceCents: 512080,
    maskedIdentifier: '•••• 4410',
    monthlyChangeCents: 31500,
    activity: _Activity.household,
  ),
  _AccountTemplate(
    id: 'postfinance-savings',
    institutionId: 'postfinance',
    name: 'E-Savings',
    type: FinancialProductType.savings,
    balanceCents: 1250000,
    maskedIdentifier: '•••• 0172',
    monthlyChangeCents: 25000,
  ),
  _AccountTemplate(
    id: 'raiffeisen-member',
    institutionId: 'raiffeisen',
    name: 'Member account',
    type: FinancialProductType.currentAccount,
    balanceCents: 734000,
    maskedIdentifier: '•••• 2289',
    monthlyChangeCents: 18800,
    activity: _Activity.household,
  ),
  _AccountTemplate(
    id: 'raiffeisen-mortgage',
    institutionId: 'raiffeisen',
    name: 'Fixed-rate mortgage',
    type: FinancialProductType.mortgage,
    balanceCents: -48000000,
    maskedIdentifier: '10-year fixed',
    monthlyChangeCents: 0,
  ),
  _AccountTemplate(
    id: 'swissquote-portfolio',
    institutionId: 'swissquote',
    name: 'Investment portfolio',
    type: FinancialProductType.investments,
    balanceCents: 4230000,
    maskedIdentifier: 'Portfolio 1847',
    monthlyChangeCents: 184020,
  ),
  _AccountTemplate(
    id: 'julius-baer-mandate',
    institutionId: 'julius-baer',
    name: 'Wealth mandate',
    type: FinancialProductType.investments,
    balanceCents: 18500000,
    maskedIdentifier: 'Mandate 5521',
    monthlyChangeCents: 412000,
  ),
  _AccountTemplate(
    id: 'pictet-portfolio',
    institutionId: 'pictet',
    name: 'Balanced portfolio',
    type: FinancialProductType.investments,
    balanceCents: 9800000,
    maskedIdentifier: 'Portfolio 3390',
    monthlyChangeCents: 165500,
  ),
  _AccountTemplate(
    id: 'frankly-3a',
    institutionId: 'frankly',
    name: 'Pillar 3a',
    type: FinancialProductType.pillar3a,
    balanceCents: 2936000,
    maskedIdentifier: '3a portfolio',
    monthlyChangeCents: 51080,
  ),
  _AccountTemplate(
    id: 'viac-3a',
    institutionId: 'viac',
    name: 'Pillar 3a',
    type: FinancialProductType.pillar3a,
    balanceCents: 1875000,
    maskedIdentifier: '3a portfolio',
    monthlyChangeCents: 38900,
  ),
  _AccountTemplate(
    id: 'finpension-3a',
    institutionId: 'finpension',
    name: 'Pillar 3a',
    type: FinancialProductType.pillar3a,
    balanceCents: 2210000,
    maskedIdentifier: '3a portfolio',
    monthlyChangeCents: 44100,
  ),
];

class _TransactionTemplate {
  const _TransactionTemplate(
    this.id,
    this.accountId,
    this.merchant,
    this.category,
    this.daysAgo,
    this.cents, {
    this.foreignCurrency,
  });
  final String? foreignCurrency;
  final String id;
  final String accountId;
  final String merchant;
  final TransactionCategory category;
  final int daysAgo;
  final int cents;
}

const _transactionTemplates = <_TransactionTemplate>[
  _TransactionTemplate(
    't1',
    'ubs-personal',
    'Migros',
    TransactionCategory.groceries,
    0,
    -8640,
  ),
  _TransactionTemplate(
    't2',
    'ubs-personal',
    'SBB Mobile',
    TransactionCategory.transport,
    1,
    -4200,
  ),
  _TransactionTemplate(
    't3',
    'ubs-personal',
    'Salary',
    TransactionCategory.income,
    8,
    685000,
  ),
  _TransactionTemplate(
    't4',
    'ubs-personal',
    'Coop City',
    TransactionCategory.shopping,
    11,
    -15425,
  ),
  _TransactionTemplate(
    't5',
    'ubs-personal',
    'CSS Insurance',
    TransactionCategory.insurance,
    14,
    -34820,
  ),
  _TransactionTemplate(
    't6',
    'ubs-personal',
    'Rent',
    TransactionCategory.housing,
    22,
    -145000,
  ),
  _TransactionTemplate(
    't7',
    'ubs-personal',
    'Salary',
    TransactionCategory.income,
    38,
    685000,
  ),
  _TransactionTemplate(
    't8',
    'ubs-card',
    'Digitec Galaxus',
    TransactionCategory.shopping,
    3,
    -24900,
  ),
  _TransactionTemplate(
    't9',
    'ubs-card',
    'Hiltl',
    TransactionCategory.dining,
    6,
    -6850,
  ),
  _TransactionTemplate(
    't10',
    'zkb-private',
    'Swisscom',
    TransactionCategory.utilities,
    9,
    -8990,
  ),
  _TransactionTemplate(
    't11',
    'zkb-private',
    'Denner',
    TransactionCategory.groceries,
    2,
    -3215,
  ),
  _TransactionTemplate(
    't12',
    'zkb-private',
    'Transfer from UBS',
    TransactionCategory.income,
    15,
    250000,
  ),
  _TransactionTemplate(
    't13',
    'postfinance-private',
    'Coop',
    TransactionCategory.groceries,
    1,
    -5730,
  ),
  _TransactionTemplate(
    't14',
    'postfinance-private',
    'SBB',
    TransactionCategory.transport,
    4,
    -8800,
  ),
  _TransactionTemplate(
    't15',
    'raiffeisen-member',
    'Volg',
    TransactionCategory.groceries,
    2,
    -2945,
  ),
  _TransactionTemplate(
    't16',
    'raiffeisen-member',
    'Mortgage interest',
    TransactionCategory.housing,
    18,
    -98000,
  ),
  // Card payments in other currencies, for the spending-abroad insight.
  _TransactionTemplate(
    't17',
    'ubs-card',
    'Amazon.de',
    TransactionCategory.shopping,
    6,
    -8930,
    foreignCurrency: 'EUR',
  ),
  _TransactionTemplate(
    't18',
    'ubs-card',
    'Trattoria da Luca, Milano',
    TransactionCategory.dining,
    13,
    -6450,
    foreignCurrency: 'EUR',
  ),
  _TransactionTemplate(
    't19',
    'ubs-card',
    'Booking.com',
    TransactionCategory.other,
    20,
    -42000,
    foreignCurrency: 'EUR',
  ),
];
