import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/accounts/widgets/account_actions.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _AccountFilter { all, cash, investing }

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  _AccountFilter _filter = _AccountFilter.all;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final institutions =
        ref.watch(institutionsProvider).value ?? const <Institution>[];
    final connections =
        ref.watch(connectionsProvider).value ?? const <InstitutionConnection>[];
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Accounts'),
      ),
      body: SafeArea(
        top: false,
        child: FinoraPage(
          child: accounts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: Text('Accounts are temporarily unavailable.'),
            ),
            data: (connectedItems) {
              final filtered = connectedItems.where(_matchesFilter).toList();
              final total = Money.sum(
                connectedItems.map((account) => account.balance),
              );
              final cash = Money.sum(
                connectedItems
                    .where((account) => account.type.isCash)
                    .map((account) => account.balance),
              );
              return ListView(
                children: [
                  Text(
                    'Your accounts, clearly organised',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Compare balances, check data health and manage each connection.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  _AccountsSummaryCard(
                    total: total,
                    cash: cash,
                    accountCount: connectedItems.length,
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    label: 'Filter accounts by product type',
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _AccountFilterChip(
                            label: 'All',
                            icon: Icons.grid_view_rounded,
                            selected: _filter == _AccountFilter.all,
                            onSelected: () =>
                                setState(() => _filter = _AccountFilter.all),
                          ),
                          const SizedBox(width: 8),
                          _AccountFilterChip(
                            label: 'Cash',
                            icon: Icons.account_balance_wallet_outlined,
                            selected: _filter == _AccountFilter.cash,
                            onSelected: () =>
                                setState(() => _filter = _AccountFilter.cash),
                          ),
                          const SizedBox(width: 8),
                          _AccountFilterChip(
                            label: 'Investing',
                            icon: Icons.trending_up,
                            selected: _filter == _AccountFilter.investing,
                            onSelected: () => setState(
                              () => _filter = _AccountFilter.investing,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SectionTitle('Connected institutions'),
                  if (connectedItems.isEmpty)
                    const _EmptyAccountsState(
                      message: 'No institutions connected yet.',
                    )
                  else if (filtered.isEmpty)
                    const _EmptyAccountsState(
                      message: 'No accounts match this filter.',
                    )
                  else
                    for (final institution in institutions)
                      if (filtered.any(
                        (item) => item.institutionId == institution.id,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _InstitutionAccountsGroup(
                            institution: institution,
                            now: now,
                            connection: connections
                                .where(
                                  (item) =>
                                      item.institutionId == institution.id,
                                )
                                .firstOrNull,
                            accounts: filtered
                                .where(
                                  (item) =>
                                      item.institutionId == institution.id,
                                )
                                .toList(),
                            onInstitutionTap: () =>
                                context.push('/institution/${institution.id}'),
                            onAccountTap: (account) =>
                                context.push('/account/${account.id}'),
                            onAction: (action, account) => _handleAccountAction(
                              action,
                              account,
                              institution,
                            ),
                          ),
                        ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/connect'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add an institution'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(FinancialAccount account) => switch (_filter) {
    _AccountFilter.all => true,
    _AccountFilter.cash => account.type.isCash,
    _AccountFilter.investing =>
      account.type.isInvestment || account.type.isRetirement,
  };

  Future<void> _handleAccountAction(
    AccountAction action,
    FinancialAccount account,
    Institution institution,
  ) async {
    switch (action) {
      case AccountAction.viewDetails:
        context.push('/account/${account.id}');
      case AccountAction.openBank:
        _showMessage(
          'A production version would securely open ${institution.name}.',
        );
      case AccountAction.refresh:
        await refreshFinancialData(ref);
        if (!mounted) return;
        _showMessage('${institution.name} is up to date.');
      case AccountAction.disconnect:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Disconnect ${institution.name}?'),
            content: Text(
              'All ${institution.name} accounts will disappear from Finora. Your accounts at the bank are not affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: finoraDanger,
                ),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          final session = ref.read(sessionProvider.notifier);
          session.disconnect(institution.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${institution.name} disconnected.'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => session.connect(institution.id),
              ),
            ),
          );
        }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountsSummaryCard extends StatelessWidget {
  const _AccountsSummaryCard({
    required this.total,
    required this.cash,
    required this.accountCount,
  });
  final Money total;
  final Money cash;
  final int accountCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Portfolio total ${formatMoney(total)}. Available cash ${formatMoney(cash)}. $accountCount connected accounts.',
      child: ExcludeSemantics(
        child: Card(
          color: finoraInk,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PORTFOLIO TOTAL',
                  style: TextStyle(
                    color: finoraSilver,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryMetric(
                        label: 'Available cash',
                        value: formatMoney(cash),
                      ),
                    ),
                    Container(
                      height: 36,
                      width: 1,
                      color: finoraSlate,
                    ),
                    Expanded(
                      child: _SummaryMetric(
                        label: 'Connected',
                        value: '$accountCount accounts',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: finoraSilver, fontSize: 11),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AccountFilterChip extends StatelessWidget {
  const _AccountFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    avatar: Icon(icon, size: 17),
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    showCheckmark: false,
    side: BorderSide(color: selected ? finoraBlue : finoraBorder),
    selectedColor: finoraSoftBlue,
    labelStyle: TextStyle(
      color: selected ? finoraBlueText : finoraInk,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _InstitutionAccountsGroup extends StatelessWidget {
  const _InstitutionAccountsGroup({
    required this.institution,
    required this.now,
    required this.connection,
    required this.accounts,
    required this.onInstitutionTap,
    required this.onAccountTap,
    required this.onAction,
  });
  final Institution institution;
  final DateTime now;
  final InstitutionConnection? connection;
  final List<FinancialAccount> accounts;
  final VoidCallback onInstitutionTap;
  final ValueChanged<FinancialAccount> onAccountTap;
  final void Function(AccountAction, FinancialAccount) onAction;

  @override
  Widget build(BuildContext context) {
    final institutionTotal = Money.sum(
      accounts.map((account) => account.balance),
    );
    final connection = this.connection;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onInstitutionTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              child: Row(
                children: [
                  InstitutionBadge(institution: institution, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          institution.name,
                          style: const TextStyle(
                            color: finoraInk,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          connection == null
                              ? 'Connection unavailable'
                              : formatSyncTime(connection.lastSyncedAt, now),
                          style: const TextStyle(
                            color: finoraMutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CompactConnectionStatus(
                    status:
                        connection?.status ?? ConnectionStatus.actionRequired,
                  ),
                  IconButton(
                    tooltip: 'Open ${institution.name} details',
                    onPressed: onInstitutionTap,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: finoraCanvas,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              '${accounts.length} ${accounts.length == 1 ? 'account' : 'accounts'} · ${formatMoney(institutionTotal)}',
              style: const TextStyle(
                color: finoraMutedInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (var index = 0; index < accounts.length; index++) ...[
            _AccessibleAccountRow(
              account: accounts[index],
              institution: institution,
              onTap: () => onAccountTap(accounts[index]),
              onAction: (action) => onAction(action, accounts[index]),
            ),
            if (index != accounts.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _CompactConnectionStatus extends StatelessWidget {
  const _CompactConnectionStatus({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ConnectionStatus.connected => ('Synced', finoraGreen),
      ConnectionStatus.stale => ('Stale', finoraWarning),
      ConnectionStatus.actionRequired => ('Action', finoraDanger),
      ConnectionStatus.manual => ('Manual', finoraSlate),
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: 'Connection status: $label',
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _AccessibleAccountRow extends StatelessWidget {
  const _AccessibleAccountRow({
    required this.account,
    required this.institution,
    required this.onTap,
    required this.onAction,
  });
  final FinancialAccount account;
  final Institution institution;
  final VoidCallback onTap;
  final ValueChanged<AccountAction> onAction;

  @override
  Widget build(BuildContext context) {
    final positive = !account.monthlyChange.isNegative;
    final changeLabel =
        '${positive ? 'up' : 'down'} ${formatMoney(account.monthlyChange.abs())}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label:
                '${account.name}, ${account.type.label}, ${formatMoney(account.balance)}, $changeLabel this month',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Color(institution.colorValue)
                              .withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          productIcon(account.type),
                          color: Color(institution.colorValue),
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name,
                              style: const TextStyle(
                                color: finoraInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${account.type.label} · ${account.maskedIdentifier}',
                              style: const TextStyle(
                                color: finoraMutedInk,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  formatMoney(account.balance),
                                  style: const TextStyle(
                                    color: finoraInk,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  formatCompactMoney(
                                    account.monthlyChange,
                                    signed: true,
                                  ),
                                  style: TextStyle(
                                    color: positive
                                        ? finoraGreen
                                        : finoraDanger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: PopupMenuButton<AccountAction>(
            tooltip: 'More actions for ${account.name}',
            icon: const Icon(Icons.more_vert),
            onSelected: onAction,
            itemBuilder: (_) => accountActionItems(institution.name),
          ),
        ),
      ],
    );
  }
}

class _EmptyAccountsState extends StatelessWidget {
  const _EmptyAccountsState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.filter_alt_off_outlined, color: finoraSlate),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: finoraInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
