import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum AccountAction { viewDetails, openBank, refresh, disconnect }

List<PopupMenuEntry<AccountAction>> accountActionItems(
  AppLocalizations l10n,
  String institutionName,
) => [
  PopupMenuItem(
    value: AccountAction.viewDetails,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.analytics_outlined),
      title: Text(l10n.actionViewInsights),
    ),
  ),
  PopupMenuItem(
    value: AccountAction.openBank,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.open_in_new),
      title: Text(l10n.actionOpenBank(institutionName)),
    ),
  ),
  PopupMenuItem(
    value: AccountAction.refresh,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.sync),
      title: Text(l10n.actionRefreshAccount),
    ),
  ),
  PopupMenuItem(
    value: AccountAction.disconnect,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.link_off, color: finoraDanger),
      title: Text(
        l10n.actionDisconnectInstitution,
        style: const TextStyle(color: finoraDanger),
      ),
    ),
  ),
];

IconData productIcon(FinancialProductType type) => switch (type) {
  FinancialProductType.currentAccount => Icons.credit_card_outlined,
  FinancialProductType.savings => Icons.savings_outlined,
  FinancialProductType.investments => Icons.candlestick_chart_outlined,
  FinancialProductType.pillar3a => Icons.nature_people_outlined,
  FinancialProductType.creditCard => Icons.payment_outlined,
  FinancialProductType.mortgage => Icons.home_work_outlined,
};
