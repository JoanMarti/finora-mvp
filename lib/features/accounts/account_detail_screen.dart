import 'dart:math' as math;

import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/accounts/widgets/account_actions.dart';
import 'package:finora/features/accounts/widgets/account_analytics_cards.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({required this.accountId, super.key});
  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _showAllRecurring = false;
  bool _recurringMonitoring = true;
  bool _balanceAlerts = true;
  int _selectedMonths = 6;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value;
    final institutions = ref.watch(institutionsProvider).value;
    final connections =
        ref.watch(connectionsProvider).value ?? const <InstitutionConnection>[];
    final now = ref.watch(clockProvider)();
    final l10n = context.l10n;
    final transactions = ref
        .watch(transactionsProvider(widget.accountId))
        .value;
    final analytics = ref
        .watch(accountAnalyticsProvider(widget.accountId))
        .value;
    if (accounts == null ||
        institutions == null ||
        transactions == null ||
        analytics == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final account = accounts
        .where((item) => item.id == widget.accountId)
        .firstOrNull;
    if (account == null) return NotFoundScreen(label: l10n.accountNotFound);
    final institution = institutions
        .where((item) => item.id == account.institutionId)
        .firstOrNull;
    if (institution == null) {
      return NotFoundScreen(label: l10n.institutionNotFound);
    }
    final connection = connections
        .where((item) => item.institutionId == institution.id)
        .firstOrNull;
    // 24 months of history (Finora Plus) unlock the longer periods.
    final periods = analytics.balanceHistory.length >= 24
        ? const [3, 6, 12, 24]
        : const [1, 3, 6];
    final selectedMonths = periods.contains(_selectedMonths)
        ? _selectedMonths
        : 6;
    final insurance = analytics.insurancePayments;
    final debtAccounts = accounts
        .where((item) => item.type.isLiability)
        .toList();
    final debtTotal = Money.sum(debtAccounts.map((item) => item.balance)).abs();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.accountInsightTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            _AccountBalanceCard(
              account: account,
              institution: institution,
              syncLabel: l10n.syncLabel(connection, now),
              monthLabel: formatMonthShort(now),
              onAction: (action) =>
                  _handleDetailAction(action, account, institution),
            ),
            if (analytics.hasBalanceHistory) ...[
              SectionTitle(l10n.accountHealthSection),
              _PeriodSelector(
                options: periods,
                selectedMonths: selectedMonths,
                onSelected: (months) =>
                    setState(() => _selectedMonths = months),
              ),
              const SizedBox(height: 12),
              BalanceEvolutionCard(
                analytics: analytics,
                months: selectedMonths,
              ),
            ] else ...[
              SectionTitle(l10n.accountHealthSection),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(l10n.moreHistoryNeeded),
                ),
              ),
            ],
            if (analytics.hasCashFlow) ...[
              SectionTitle(l10n.cashFlowSection),
              CashFlowCard(
              analytics: analytics,
              // Cash flow is kept for six months, whatever the plan.
              months: math.min(selectedMonths, 6),
            ),
            ],
            if (analytics.spendingCategories.isNotEmpty) ...[
              SectionTitle(l10n.spendingSection),
              SpendingCategoriesCard(analytics: analytics),
            ],
            if (analytics.recurringPayments.isNotEmpty) ...[
              SectionTitle(
                l10n.recurringPaymentsSection,
                action: analytics.recurringPayments.length > 3
                    ? TextButton(
                        onPressed: () => setState(
                          () => _showAllRecurring = !_showAllRecurring,
                        ),
                        child: Text(
                          _showAllRecurring ? l10n.showLess : l10n.seeAll,
                        ),
                      )
                    : null,
              ),
              RecurringPaymentsCard(
                analytics: analytics,
                showAll: _showAllRecurring,
                now: now,
              ),
            ],
            if (analytics.hasCashFlow) ...[
              SectionTitle(l10n.improvementsSection),
              if (insurance.length >= 2) ...[
                _OpportunityCard(
                  icon: Icons.health_and_safety_outlined,
                  accent: finoraSlate,
                  eyebrow: l10n.coverageEyebrow,
                  title: l10n.coverageTitle,
                  description: l10n.coverageBody(
                    insurance.length,
                    formatMoney(
                      Money.sum(insurance.map((item) => item.amount.abs())),
                    ),
                  ),
                  value: l10n.coverageValue,
                  actionLabel: l10n.coverageAction,
                  onPressed: () =>
                      _showServiceMessage(l10n.coverageConsentMessage),
                ),
                const SizedBox(height: 12),
              ],
              _OpportunityCard(
                icon: Icons.account_balance_outlined,
                accent: finoraBlue,
                eyebrow: l10n.debtEyebrow,
                title: l10n.debtTitle,
                description: debtAccounts.isEmpty
                    ? l10n.debtBodyNone
                    : l10n.debtBodySome(
                        l10n.debtAccountCount(debtAccounts.length),
                        formatMoney(debtTotal),
                      ),
                value: debtAccounts.isEmpty
                    ? l10n.debtValueNone
                    : l10n.debtValueSome,
                actionLabel: debtAccounts.isEmpty
                    ? l10n.connectDebtAccounts
                    : l10n.openAccount(debtAccounts.first.name),
                onPressed: debtAccounts.isEmpty
                    ? () => context.push('/connect')
                    : () => context.push('/account/${debtAccounts.first.id}'),
              ),
              SectionTitle(l10n.monitoringSection),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.autorenew, color: finoraBlue),
                      title: Text(
                        l10n.recurringChangesTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(l10n.recurringChangesBody),
                      value: _recurringMonitoring,
                      onChanged: (value) =>
                          setState(() => _recurringMonitoring = value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        color: finoraBlue,
                      ),
                      title: Text(
                        l10n.lowBalanceTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(l10n.lowBalanceBody),
                      value: _balanceAlerts,
                      onChanged: (value) =>
                          setState(() => _balanceAlerts = value),
                    ),
                  ],
                ),
              ),
            ],
            SectionTitle(
              l10n.recentTransactionsSection,
              action: TextButton(
                onPressed: () => context.push('/activity'),
                child: Text(l10n.viewAll),
              ),
            ),
            Card(
              child: transactions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l10n.noRecentTransactions)),
                    )
                  : Column(
                      children: [
                        for (final item in transactions)
                          TransactionTile(transaction: item),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Card(
              color: finoraSoftBlue,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: finoraBlue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.insightsDisclaimer,
                        style: const TextStyle(
                          color: finoraMutedInk,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleDetailAction(
    AccountAction action,
    FinancialAccount account,
    Institution institution,
  ) {
    final l10n = context.l10n;
    switch (action) {
      case AccountAction.viewDetails:
        break;
      case AccountAction.openBank:
        _showServiceMessage(l10n.openBankMessage(institution.name));
      case AccountAction.refresh:
        refreshFinancialData(ref).then((_) {
          if (mounted) _showServiceMessage(l10n.upToDateMessage(account.name));
        });
      case AccountAction.disconnect:
        context.go('/accounts');
        _showServiceMessage(l10n.useInstitutionMenuToDisconnect);
    }
  }
}

class _AccountBalanceCard extends StatelessWidget {
  const _AccountBalanceCard({
    required this.account,
    required this.institution,
    required this.syncLabel,
    required this.monthLabel,
    required this.onAction,
  });

  final FinancialAccount account;
  final Institution institution;
  final String syncLabel;
  final String monthLabel;
  final ValueChanged<AccountAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: finoraInk,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InstitutionBadge(institution: institution),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        institution.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        syncLabel,
                        style: const TextStyle(
                          color: finoraSilver,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<AccountAction>(
                  tooltip: context.l10n.moreActionsFor(account.name),
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: onAction,
                  itemBuilder: (_) =>
                      accountActionItems(context.l10n, institution.name),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              account.name,
              style: const TextStyle(color: finoraSilver),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(
                  account.balance,
                  signed: account.balance.isNegative,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    account.maskedIdentifier,
                    style: const TextStyle(color: finoraSilver),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: (account.monthlyChange.isNegative
                              ? finoraDanger
                              : finoraGreen)
                          .withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          context.l10n.changeInMonth(
                            formatCompactMoney(
                              account.monthlyChange,
                              signed: true,
                            ),
                            monthLabel,
                          ),
                          style: TextStyle(
                            color: account.monthlyChange.isNegative
                                ? const Color(0xFFFFB4AB)
                                : const Color(0xFF8ED8B9),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedMonths,
    required this.onSelected,
    required this.options,
  });
  final int selectedMonths;
  final ValueChanged<int> onSelected;

  /// Plus members get 12 and 24 months on top of the free periods.
  final List<int> options;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.selectPeriod,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: [
            for (final months in options)
              ButtonSegment(
                value: months,
                label: Text(
                  options.length > 3
                      ? context.l10n.monthsShort(months)
                      : context.l10n.monthsCount(months),
                ),
              ),
          ],
          selected: {selectedMonths},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onSelected(selection.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.comfortable,
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.icon,
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.value,
    required this.actionLabel,
    required this.onPressed,
  });
  final IconData icon;
  final Color accent;
  final String eyebrow;
  final String title;
  final String description;
  final String value;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textAccent = finoraAccessibleAccent(accent);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: .12),
                  foregroundColor: accent,
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: TextStyle(
                          color: textAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        style: const TextStyle(
                          color: finoraInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(color: finoraMutedInk, height: 1.35),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: textAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
