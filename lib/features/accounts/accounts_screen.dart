import 'package:finora/app/layout.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/application/health.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/accounts/account_detail_screen.dart';
import 'package:finora/features/accounts/widgets/account_actions.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
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

  /// Account shown next to the list on wide screens.
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < finoraWideContentWidth) {
          return _buildList(context, wide: false);
        }
        final visible = (ref.watch(accountsProvider).value ?? const [])
            .where(_matchesFilter)
            .map((account) => account.id)
            .toList();
        final selected = visible.contains(_selected)
            ? _selected
            : visible.firstOrNull;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 440,
              child: _buildList(context, wide: true, selected: selected),
            ),
            const VerticalDivider(width: 1, color: finoraBorder),
            Expanded(
              child: selected == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          context.l10n.accountsSelectHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: finoraMutedInk),
                        ),
                      ),
                    )
                  : AccountDetailScreen(
                      key: ValueKey(selected),
                      accountId: selected,
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openAccount(FinancialAccount account, {required bool wide}) {
    if (wide) {
      setState(() => _selected = account.id);
    } else {
      context.push('/account/${account.id}');
    }
  }

  Widget _buildList(
    BuildContext context, {
    required bool wide,
    String? selected,
  }) {
    final accounts = ref.watch(accountsProvider);
    final institutions =
        ref.watch(institutionsProvider).value ?? const <Institution>[];
    final connections =
        ref.watch(connectionsProvider).value ?? const <InstitutionConnection>[];
    final now = ref.watch(clockProvider)();
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.navAccounts),
      ),
      body: SafeArea(
        top: false,
        child: FinoraPage(
          child: accounts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(l10n.accountsUnavailable)),
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
                    l10n.accountsTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.accountsSubtitle,
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
                    label: l10n.filterAccountsLabel,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _AccountFilterChip(
                            label: l10n.filterAll,
                            icon: Icons.grid_view_rounded,
                            selected: _filter == _AccountFilter.all,
                            onSelected: () =>
                                setState(() => _filter = _AccountFilter.all),
                          ),
                          const SizedBox(width: 8),
                          _AccountFilterChip(
                            label: l10n.filterCash,
                            icon: Icons.account_balance_wallet_outlined,
                            selected: _filter == _AccountFilter.cash,
                            onSelected: () =>
                                setState(() => _filter = _AccountFilter.cash),
                          ),
                          const SizedBox(width: 8),
                          _AccountFilterChip(
                            label: l10n.filterInvesting,
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
                  SectionTitle(l10n.connectedInstitutionsSection),
                  if (connectedItems.isEmpty)
                    _EmptyAccountsState(message: l10n.noInstitutionsConnected)
                  else if (filtered.isEmpty)
                    _EmptyAccountsState(message: l10n.noAccountsMatchFilter)
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
                            selectedAccountId: selected,
                            onAccountTap: (account) =>
                                _openAccount(account, wide: wide),
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
                    label: Text(l10n.addInstitutionTitle),
                  ),
                  SectionTitle(l10n.otherAssetsSection),
                  const _OtherAssetsTile(),
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
    final l10n = context.l10n;
    switch (action) {
      case AccountAction.viewDetails:
        context.push('/account/${account.id}');
      case AccountAction.openBank:
        _showMessage(l10n.openBankMessage(institution.name));
      case AccountAction.refresh:
        await refreshFinancialData(ref);
        if (!mounted) return;
        _showMessage(l10n.upToDateMessage(institution.name));
      case AccountAction.disconnect:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.disconnectTitle(institution.name)),
            content: Text(l10n.disconnectBody(institution.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: finoraDanger,
                ),
                child: Text(l10n.disconnect),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          final session = ref.read(sessionProvider.notifier);
          session.disconnect(institution.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.disconnectedMessage(institution.name)),
              action: SnackBarAction(
                label: l10n.commonUndo,
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
    final l10n = context.l10n;
    return Semantics(
      label: l10n.portfolioSemantics(
        formatMoney(total),
        formatMoney(cash),
        l10n.accountCount(accountCount),
      ),
      child: ExcludeSemantics(
        child: HeroCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.portfolioTotal.toUpperCase(),
                  style: const TextStyle(
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
                        label: l10n.availableCash,
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
                        label: l10n.connectedLabel,
                        value: l10n.accountCount(accountCount),
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
    avatar: Icon(
      icon,
      size: 17,
      color: selected ? finoraWhite : finoraBlueText,
    ),
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
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
    this.selectedAccountId,
  });
  final String? selectedAccountId;
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
                          context.l10n.syncLabel(connection, now),
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
                    tooltip: context.l10n.openInstitutionDetails(
                      institution.name,
                    ),
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
              '${context.l10n.accountCount(accounts.length)} · ${formatMoney(institutionTotal)}',
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
              selected: accounts[index].id == selectedAccountId,
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
    final label = context.l10n.connectionStatusShort(status);
    final color = switch (status) {
      ConnectionStatus.connected => finoraGreen,
      ConnectionStatus.stale => finoraWarning,
      ConnectionStatus.actionRequired => finoraDanger,
      ConnectionStatus.manual => finoraSlate,
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: context.l10n.connectionStatusLabel(label),
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
    this.selected = false,
  });
  final FinancialAccount account;
  final Institution institution;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<AccountAction> onAction;

  @override
  Widget build(BuildContext context) {
    final positive = !account.monthlyChange.isNegative;
    final l10n = context.l10n;
    final changeAmount = formatMoney(account.monthlyChange.abs());
    final changeLabel = positive
        ? l10n.changeUp(changeAmount)
        : l10n.changeDown(changeAmount);
    final typeLabel = l10n.productType(account.type);
    return ColoredBox(
      color: selected ? finoraSoftBlue : Colors.transparent,
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.accountRowSemantics(
              account.name,
              typeLabel,
              formatMoney(account.balance),
              changeLabel,
            ),
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
                          borderRadius: BorderRadius.circular(finoraRadiusControl),
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
                              '$typeLabel · ${account.maskedIdentifier}',
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
            tooltip: l10n.moreActionsFor(account.name),
            icon: const Icon(Icons.more_vert),
            onSelected: onAction,
            itemBuilder: (_) => accountActionItems(l10n, institution.name),
          ),
        ),
      ],
      ),
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

/// Entry point to property, vehicles, crypto and other manual assets.
class _OtherAssetsTile extends ConsumerWidget {
  const _OtherAssetsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assets = ref.watch(manualAssetsProvider);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: finoraSoftBlue,
          foregroundColor: finoraBlueText,
          child: Icon(Icons.home_work_outlined, size: 20),
        ),
        title: Text(
          l10n.assetsTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          assets.isEmpty
              ? l10n.assetsTileEmpty
              : l10n.assetsSummary(assets.length, formatMoneyWhole(assets.total)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/assets'),
      ),
    );
  }
}
