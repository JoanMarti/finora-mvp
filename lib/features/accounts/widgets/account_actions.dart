import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:flutter/material.dart';

enum AccountAction { viewDetails, openBank, refresh, disconnect }

List<PopupMenuEntry<AccountAction>> accountActionItems(
  String institutionName,
) => [
  const PopupMenuItem(
    value: AccountAction.viewDetails,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.analytics_outlined),
      title: Text('View account insights'),
    ),
  ),
  PopupMenuItem(
    value: AccountAction.openBank,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.open_in_new),
      title: Text('Open $institutionName'),
    ),
  ),
  const PopupMenuItem(
    value: AccountAction.refresh,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.sync),
      title: Text('Refresh account'),
    ),
  ),
  PopupMenuItem(
    value: AccountAction.disconnect,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.link_off, color: finoraDanger),
      title: Text(
        'Disconnect institution',
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
