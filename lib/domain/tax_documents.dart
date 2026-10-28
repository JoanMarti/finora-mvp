import 'package:finora/domain/assets.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/profile.dart';

/// Papers a Swiss tax return usually needs.
enum TaxDocumentKind {
  salaryCertificate,
  selfEmployedAccounts,
  pensionCertificate,
  bankStatement,
  pillar3aCertificate,
  mortgageInterest,
  propertyCosts,
  loanInterest,
  healthInsurance,
  childcareCosts,
  donations,
}

/// One paper to collect, for one institution when it comes from a bank.
class TaxDocument {
  const TaxDocument(this.kind, {this.institutionId, this.optional = false});

  final TaxDocumentKind kind;
  final String? institutionId;

  /// Worth collecting only when it applies, e.g. receipts for donations.
  final bool optional;

  /// Stable key used to remember that the paper is ready.
  String get id =>
      institutionId == null ? kind.name : '${kind.name}:$institutionId';
}

/// The papers for one tax year, built from accounts and profile.
class TaxDocumentChecklist {
  const TaxDocumentChecklist({
    required this.taxYear,
    required this.documents,
  });

  /// The return being prepared: until March it is last year's, from April
  /// on the current year's (its papers arrive in January).
  static int taxYearFor(DateTime now) =>
      now.month <= 3 ? now.year - 1 : now.year;

  factory TaxDocumentChecklist.build({
    required DateTime now,
    required List<FinancialAccount> accounts,
    required UserProfile profile,
    List<ManualAsset> manualAssets = const [],
    bool hasLoans = false,
  }) {
    final employment = profile.employment;
    final owns =
        profile.housing == Housing.owning ||
        manualAssets.any((asset) => asset.kind == ManualAssetKind.property) ||
        accounts.any((account) => account.type == FinancialProductType.mortgage);

    // One statement per institution, in the order the accounts come.
    final institutionsFor = <TaxDocumentKind, List<String>>{};
    void add(TaxDocumentKind kind, String institutionId) {
      final list = institutionsFor.putIfAbsent(kind, () => []);
      if (!list.contains(institutionId)) list.add(institutionId);
    }

    for (final account in accounts) {
      switch (account.type) {
        case FinancialProductType.currentAccount ||
            FinancialProductType.savings ||
            FinancialProductType.investments:
          add(TaxDocumentKind.bankStatement, account.institutionId);
        case FinancialProductType.pillar3a:
          add(TaxDocumentKind.pillar3aCertificate, account.institutionId);
        case FinancialProductType.mortgage:
          add(TaxDocumentKind.mortgageInterest, account.institutionId);
        case FinancialProductType.creditCard:
          break;
      }
    }

    List<TaxDocument> perInstitution(TaxDocumentKind kind) => [
      for (final id in institutionsFor[kind] ?? const <String>[])
        TaxDocument(kind, institutionId: id),
    ];

    final working = employment == null || employment == Employment.employee;
    return TaxDocumentChecklist(
      taxYear: taxYearFor(now),
      documents: [
        if (working) const TaxDocument(TaxDocumentKind.salaryCertificate),
        if (employment == Employment.selfEmployed)
          const TaxDocument(TaxDocumentKind.selfEmployedAccounts),
        if (working) const TaxDocument(TaxDocumentKind.pensionCertificate),
        ...perInstitution(TaxDocumentKind.bankStatement),
        ...perInstitution(TaxDocumentKind.pillar3aCertificate),
        ...perInstitution(TaxDocumentKind.mortgageInterest),
        if (owns) const TaxDocument(TaxDocumentKind.propertyCosts),
        if (hasLoans) const TaxDocument(TaxDocumentKind.loanInterest),
        const TaxDocument(TaxDocumentKind.healthInsurance),
        if ((profile.children ?? 0) > 0)
          const TaxDocument(TaxDocumentKind.childcareCosts),
        const TaxDocument(TaxDocumentKind.donations, optional: true),
      ],
    );
  }

  final int taxYear;
  final List<TaxDocument> documents;

  /// Last day to file in most cantons (extensions are usually possible).
  DateTime get deadline => DateTime(taxYear + 1, 3, 31);

  /// The key under which a paper is remembered as ready.
  String keyOf(TaxDocument document) => '$taxYear:${document.id}';

  int readyCount(Set<String> ready) =>
      documents.where((document) => ready.contains(keyOf(document))).length;

  /// Share of the required papers that are ready (optional ones excluded).
  double progress(Set<String> ready) {
    final required = documents.where((document) => !document.optional);
    if (required.isEmpty) return 1;
    final done = required
        .where((document) => ready.contains(keyOf(document)))
        .length;
    return done / required.length;
  }
}
