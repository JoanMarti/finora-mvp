import 'package:finora/domain/models.dart';
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
