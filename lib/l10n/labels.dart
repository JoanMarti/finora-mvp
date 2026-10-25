import 'package:finora/domain/assets.dart';
import 'package:finora/domain/health.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/l10n/generated/app_localizations.dart';
import 'package:finora/shared/formatters.dart';
import 'package:intl/intl.dart';

/// Localized names for domain values. The domain stays language-free; the
/// UI asks these helpers for text.
extension FinoraLabels on AppLocalizations {
  String productType(FinancialProductType type) => switch (type) {
    FinancialProductType.currentAccount => productCurrentAccount,
    FinancialProductType.savings => productSavings,
    FinancialProductType.investments => productInvestments,
    FinancialProductType.pillar3a => productPillar3a,
    FinancialProductType.creditCard => productCreditCard,
    FinancialProductType.mortgage => productMortgage,
  };

  String transactionCategory(TransactionCategory category) =>
      switch (category) {
        TransactionCategory.income => categoryIncome,
        TransactionCategory.groceries => categoryGroceries,
        TransactionCategory.transport => categoryTransport,
        TransactionCategory.utilities => categoryUtilities,
        TransactionCategory.shopping => categoryShopping,
        TransactionCategory.insurance => categoryInsurance,
        TransactionCategory.dining => categoryDining,
        TransactionCategory.housing => categoryHousing,
        TransactionCategory.other => categoryOther,
      };

  String billCategory(BillCategory category) => switch (category) {
    BillCategory.healthInsurance => billHealthInsurance,
    BillCategory.householdInsurance => billHouseholdInsurance,
    BillCategory.phoneInternet => billPhoneInternet,
    BillCategory.membership => billMembership,
    BillCategory.streaming => billStreaming,
    BillCategory.electricity => billElectricity,
    BillCategory.radioTvFee => billRadioTvFee,
  };

  String billCadence(BillCadence cadence) => switch (cadence) {
    BillCadence.monthly => cadenceMonthly,
    BillCadence.monthlyEquivalent => cadenceMonthlyEquivalent,
  };

  String connectionStatus(ConnectionStatus status) => switch (status) {
    ConnectionStatus.connected => statusHealthy,
    ConnectionStatus.stale => statusNeedsRefresh,
    ConnectionStatus.actionRequired => statusActionNeeded,
    ConnectionStatus.manual => statusManual,
  };

  String connectionStatusShort(ConnectionStatus status) => switch (status) {
    ConnectionStatus.connected => statusSynced,
    ConnectionStatus.stale => statusStale,
    ConnectionStatus.actionRequired => statusActionNeeded,
    ConnectionStatus.manual => statusManual,
  };

  /// `Today`, `Yesterday` or a short date such as `12 Oct`.
  String relativeDay(DateTime date, DateTime now) {
    if (_isSameDay(date, now)) return dateToday;
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return dateYesterday;
    }
    return DateFormat.MMMd(localeName).format(date);
  }

  String dueDate(DateTime due, DateTime now) {
    if (_isSameDay(due, now)) return dueToday;
    if (_isSameDay(due, now.add(const Duration(days: 1)))) return dueTomorrow;
    return dueOn(DateFormat.MMMd(localeName).format(due));
  }

  /// How fresh a connection is, e.g. `Updated 4 min ago`.
  String syncTime(DateTime syncedAt, DateTime now) {
    final age = now.difference(syncedAt);
    if (age.inMinutes < 1) return syncJustNow;
    if (age.inMinutes < 60) return syncMinutesAgo(age.inMinutes);
    if (age.inHours < 24) return syncHoursAgo(age.inHours);
    if (age.inDays == 1) return syncYesterday;
    return syncDaysAgo(age.inDays);
  }

  String alertTitle(FinoraAlert alert) => switch (alert.kind) {
    AlertKind.consentRequired => alertConsentTitle(alert.subject),
    AlertKind.staleConnection => alertStaleTitle(alert.subject),
    AlertKind.manualValueOutdated => alertManualTitle(alert.subject),
    AlertKind.billDue => alertBillTitle(alert.subject),
  };

  String alertDescription(FinoraAlert alert) => switch (alert.kind) {
    AlertKind.consentRequired => alertConsentBody,
    AlertKind.staleConnection => alertStaleBody,
    AlertKind.manualValueOutdated => alertManualBody,
    AlertKind.billDue => alertBillBody(
      alert.bill == null ? '' : billCategory(alert.bill!),
      alert.amount == null ? '' : formatMoney(alert.amount!),
      inDays(alert.daysUntilDue ?? 0),
    ),
  };

  String syncLabel(InstitutionConnection? connection, DateTime now) =>
      connection == null
      ? connectionUnavailable
      : syncTime(connection.lastSyncedAt, now);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Texts for savings opportunities. Every sentence names the evidence it is
/// based on, so the user can see why an offer appears.
extension OpportunityLabels on AppLocalizations {
  String opportunityTitle(Opportunity item) => offerKindTitle(item.kind);

  String offerKindTitle(OpportunityKind kind) => switch (kind) {
    OpportunityKind.healthInsuranceSwitch => offerHealthTitle,
    OpportunityKind.insuranceReview => offerInsuranceReviewTitle,
    OpportunityKind.idleCash => offerIdleCashTitle,
    OpportunityKind.pillar3aRoom => offerPillarRoomTitle,
    OpportunityKind.pillar3aOpen => offerPillarOpenTitle,
    OpportunityKind.mortgageRenewal => offerMortgageTitle,
    OpportunityKind.cardFees => offerCardTitle,
    OpportunityKind.telecomPlan => offerTelecomTitle,
    OpportunityKind.subscriptionsReview => offerSubscriptionsTitle,
    OpportunityKind.bankFees => offerBankFeesTitle,
  };

  String opportunityReason(Opportunity item) {
    final amount = item.amount == null ? '' : formatMoney(item.amount!);
    return switch (item.kind) {
      OpportunityKind.healthInsuranceSwitch => offerHealthReason(
        amount,
        item.subject ?? '',
        item.percent ?? 0,
      ),
      OpportunityKind.insuranceReview => offerInsuranceReviewReason(
        item.count ?? 0,
        amount,
      ),
      OpportunityKind.idleCash => offerIdleCashReason(amount),
      OpportunityKind.pillar3aRoom => offerPillarRoomReason(amount),
      OpportunityKind.pillar3aOpen => offerPillarOpenReason(amount),
      OpportunityKind.mortgageRenewal => offerMortgageReason(amount),
      OpportunityKind.cardFees => offerCardReason(item.subject ?? ''),
      OpportunityKind.telecomPlan => offerTelecomReason(
        amount,
        item.subject ?? '',
      ),
      OpportunityKind.subscriptionsReview => offerSubscriptionsReason(
        item.count ?? 0,
        amount,
      ),
      OpportunityKind.bankFees => offerBankFeesReason(item.count ?? 0),
    };
  }

  String opportunityAction(Opportunity item) => switch (item.kind) {
    OpportunityKind.healthInsuranceSwitch => offerHealthAction,
    OpportunityKind.insuranceReview => offerInsuranceReviewAction,
    OpportunityKind.idleCash => offerIdleCashAction,
    OpportunityKind.pillar3aRoom ||
    OpportunityKind.pillar3aOpen => offerPillarAction,
    OpportunityKind.mortgageRenewal => offerMortgageAction,
    OpportunityKind.cardFees => offerCardAction,
    OpportunityKind.telecomPlan => offerTelecomAction,
    OpportunityKind.subscriptionsReview => offerSubscriptionsAction,
    OpportunityKind.bankFees => offerBankFeesAction,
  };

  String opportunityCategory(OpportunityCategory category) =>
      switch (category) {
        OpportunityCategory.insurance => offerCategoryInsurance,
        OpportunityCategory.banking => offerCategoryBanking,
        OpportunityCategory.pensions => offerCategoryPensions,
        OpportunityCategory.mortgage => offerCategoryMortgage,
        OpportunityCategory.telecom => offerCategoryTelecom,
        OpportunityCategory.budget => offerCategoryBudget,
      };

  /// How Finora is paid, in plain words, for the disclosure line.
  String revenueDisclosure(RevenueModel revenue) => switch (revenue) {
    RevenueModel.leadFee => offerDisclosureLeadFee,
    RevenueModel.commission => offerDisclosureCommission,
    RevenueModel.affiliate => offerDisclosureAffiliate,
    RevenueModel.none => offerDisclosureNone,
  };

  /// `CHF 210 – 630 a year`, or `null` when there is no estimate.
  String? opportunitySaving(Opportunity item) {
    final low = item.savingLow;
    final high = item.savingHigh;
    if (low == null || high == null) return null;
    return offerSavingRange(formatMoneyWhole(low), formatMoneyWhole(high));
  }
}

/// Texts for the financial health check and manual assets.
extension HealthLabels on AppLocalizations {
  String healthStatus(HealthStatus status) => switch (status) {
    HealthStatus.good => healthStatusGood,
    HealthStatus.fair => healthStatusFair,
    HealthStatus.attention => healthStatusAttention,
    HealthStatus.missingData => healthStatusMissing,
  };

  String healthFactorTitle(HealthFactorKind kind) => switch (kind) {
    HealthFactorKind.emergencyFund => healthEmergencyTitle,
    HealthFactorKind.savingsRate => healthSavingsRateTitle,
    HealthFactorKind.pillar3a => healthPillarTitle,
    HealthFactorKind.housing => healthHousingTitle,
    HealthFactorKind.retirement => healthRetirementTitle,
    HealthFactorKind.fixedCosts => healthFixedCostsTitle,
  };

  String healthFactorDetail(HealthFactor factor) {
    int percent(double? value) => ((value ?? 0) * 100).round();
    return switch (factor.kind) {
      HealthFactorKind.emergencyFund => factor.ratio == null
          ? healthNoSpendingData
          : healthEmergencyDetail(
              factor.ratio!.toStringAsFixed(1),
              formatMoneyWhole(factor.target ?? Money.zero),
            ),
      HealthFactorKind.savingsRate => factor.score == null
          ? healthNoSpendingData
          : healthSavingsRateDetail(percent(factor.ratio)),
      HealthFactorKind.pillar3a => healthPillarDetail(
        formatMoneyWhole(factor.amount ?? Money.zero),
        formatMoneyWhole(factor.target ?? Money.zero),
      ),
      HealthFactorKind.housing => factor.score == null
          ? healthHousingMissing(formatMoneyWhole(factor.amount ?? Money.zero))
          : [
              healthHousingLtv(percent(factor.ratio)),
              if (factor.secondRatio != null)
                healthHousingAffordability(percent(factor.secondRatio)),
            ].join(' '),
      HealthFactorKind.retirement => [
        healthRetirementDetail(percent(factor.ratio)),
        if (factor.isExample) healthExampleFigures,
      ].join(' '),
      HealthFactorKind.fixedCosts => factor.score == null
          ? healthNoSpendingData
          : healthFixedCostsDetail(percent(factor.ratio)),
    };
  }

  String healthFactorAction(HealthFactor factor) => switch (factor.kind) {
    HealthFactorKind.emergencyFund => healthEmergencyAction,
    HealthFactorKind.savingsRate => healthSavingsRateAction,
    HealthFactorKind.pillar3a =>
      factor.route == '/offers' ? offerPillarAction : healthPillarAction,
    HealthFactorKind.housing =>
      factor.score == null ? healthHousingAddAction : offerMortgageAction,
    HealthFactorKind.retirement => healthRetirementAction,
    HealthFactorKind.fixedCosts => healthFixedCostsAction,
  };

  String assetKind(ManualAssetKind kind) => switch (kind) {
    ManualAssetKind.property => assetKindProperty,
    ManualAssetKind.vehicle => assetKindVehicle,
    ManualAssetKind.crypto => assetKindCrypto,
    ManualAssetKind.other => assetKindOther,
  };
}
