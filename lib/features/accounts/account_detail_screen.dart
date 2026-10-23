import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/accounts/widgets/account_actions.dart';
import 'package:finora/features/accounts/widgets/account_analytics_cards.dart';
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
    if (account == null) return const NotFoundScreen(label: 'Account not found');
    final institution = institutions
        .where((item) => item.id == account.institutionId)
        .firstOrNull;
    if (institution == null) {
      return const NotFoundScreen(label: 'Institution not found');
    }
    final connection = connections
        .where((item) => item.institutionId == institution.id)
        .firstOrNull;
    final insurance = analytics.insurancePayments;
    final debtAccounts = accounts
        .where((item) => item.type.isLiability)
        .toList();
    final debtTotal = Money.sum(debtAccounts.map((item) => item.balance)).abs();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Account insight'),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            _AccountBalanceCard(
              account: account,
              institution: institution,
              syncLabel: connection == null
                  ? 'Connection unavailable'
                  : formatSyncTime(connection.lastSyncedAt, now),
              monthLabel: formatMonthShort(now),
              onAction: (action) =>
                  _handleDetailAction(action, account, institution),
            ),
            if (analytics.hasBalanceHistory) ...[
              const SectionTitle('Account health'),
              _PeriodSelector(
                selectedMonths: _selectedMonths,
                onSelected: (months) =>
                    setState(() => _selectedMonths = months),
              ),
              const SizedBox(height: 12),
              BalanceEvolutionCard(
                analytics: analytics,
                months: _selectedMonths,
              ),
            ] else ...[
              const SectionTitle('Account health'),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'More history is needed before Finora can explain this account.',
                  ),
                ),
              ),
            ],
            if (analytics.hasCashFlow) ...[
              const SectionTitle('Cash flow'),
              CashFlowCard(analytics: analytics, months: _selectedMonths),
            ],
            if (analytics.spendingCategories.isNotEmpty) ...[
              const SectionTitle('Spending'),
              SpendingCategoriesCard(analytics: analytics),
            ],
            if (analytics.recurringPayments.isNotEmpty) ...[
              SectionTitle(
                'Recurring payments',
                action: analytics.recurringPayments.length > 3
                    ? TextButton(
                        onPressed: () => setState(
                          () => _showAllRecurring = !_showAllRecurring,
                        ),
                        child: Text(
                          _showAllRecurring ? 'Show less' : 'See all',
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
              const SectionTitle('Potential improvements'),
              if (insurance.length >= 2) ...[
                _OpportunityCard(
                  icon: Icons.health_and_safety_outlined,
                  accent: finoraSlate,
                  eyebrow: 'COVERAGE CHECK · PARTNER OPTION',
                  title: 'Review insurance in one place',
                  description:
                      '${insurance.length} insurance payments were detected '
                      '(${formatMoney(Money.sum(insurance.map((item) => item.amount.abs())))} a month). '
                      'A guided comparison could reveal duplicated cover or a better deductible setup.',
                  value: 'Illustrative potential: CHF 35–70 / month',
                  actionLabel: 'Explore a coverage check',
                  onPressed: () => _showServiceMessage(
                    'Coverage comparison would open only with your consent.',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _OpportunityCard(
                icon: Icons.account_balance_outlined,
                accent: finoraBlue,
                eyebrow: 'DEBT VIEW · OPTIONAL',
                title: 'See the true cost of your debt',
                description: debtAccounts.isEmpty
                    ? 'No cards or loans are connected yet. Add them to compare rates and see whether consolidation deserves a closer look.'
                    : '${debtAccounts.length} debt ${debtAccounts.length == 1 ? 'account is' : 'accounts are'} connected, '
                          'totalling ${formatMoney(debtTotal)}. Compare their rates before deciding what to repay first.',
                value: debtAccounts.isEmpty
                    ? 'No savings estimate until debt data is available'
                    : 'Rates are not available from the demo data yet',
                actionLabel: debtAccounts.isEmpty
                    ? 'Connect debt accounts'
                    : 'Open ${debtAccounts.first.name}',
                onPressed: debtAccounts.isEmpty
                    ? () => context.push('/connect')
                    : () => context.push('/account/${debtAccounts.first.id}'),
              ),
              const SectionTitle('Monitoring'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.autorenew, color: finoraBlue),
                      title: const Text(
                        'Recurring payment changes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Alert me when a regular bill changes',
                      ),
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
                      title: const Text(
                        'Low balance forecast',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Warn me before planned bills put cash at risk',
                      ),
                      value: _balanceAlerts,
                      onChanged: (value) =>
                          setState(() => _balanceAlerts = value),
                    ),
                  ],
                ),
              ),
            ],
            SectionTitle(
              'Recent transactions',
              action: TextButton(
                onPressed: () => context.push('/activity'),
                child: const Text('View all'),
              ),
            ),
            Card(
              child: transactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No recent transactions')),
                    )
                  : Column(
                      children: [
                        for (final item in transactions)
                          TransactionTile(transaction: item),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            const Card(
              color: finoraSoftBlue,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: finoraBlue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Insights use mock transaction patterns and are not financial advice. Finora never applies for or switches a product without explicit consent.',
                        style: TextStyle(
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
    switch (action) {
      case AccountAction.viewDetails:
        break;
      case AccountAction.openBank:
        _showServiceMessage(
          'A production version would securely open ${institution.name}.',
        );
      case AccountAction.refresh:
        refreshFinancialData(ref).then((_) {
          if (mounted) _showServiceMessage('${account.name} is up to date.');
        });
      case AccountAction.disconnect:
        context.go('/accounts');
        _showServiceMessage(
          'Use the institution menu to review and confirm disconnection.',
        );
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
                  tooltip: 'More actions for ${account.name}',
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: onAction,
                  itemBuilder: (_) => accountActionItems(institution.name),
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
                          '${formatCompactMoney(account.monthlyChange, signed: true)} in $monthLabel',
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
  });
  final int selectedMonths;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Select account analysis period',
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1 month')),
            ButtonSegment(value: 3, label: Text('3 months')),
            ButtonSegment(value: 6, label: Text('6 months')),
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
