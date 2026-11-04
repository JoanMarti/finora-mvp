import 'package:finora/app/layout.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/transaction_filter.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/category_sheet.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String _query = '';
  TransactionFilter _filter = const TransactionFilter();

  bool _matches(FinancialTransaction item, {TransactionFilter? filter}) {
    if (!(filter ?? _filter).matches(item, ref.read(clockProvider)())) {
      return false;
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return item.merchant.toLowerCase().contains(query) ||
        context.l10n
            .transactionCategory(item.category)
            .toLowerCase()
            .contains(query);
  }

  Future<void> _copyCsv(List<FinancialTransaction> items) async {
    final rows = [
      'date,merchant,category,amount,currency,account',
      for (final item in items)
        [
          item.bookedAt.toIso8601String().substring(0, 10),
          _csvField(item.merchant),
          item.category.name,
          item.amount.amount.toStringAsFixed(2),
          item.amount.currency,
          item.accountId,
        ].join(','),
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.csvCopied(items.length))),
    );
  }

  Future<void> _openFilters(
    List<FinancialTransaction> items,
    List<FinancialAccount> accounts,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FilterSheet(
      initial: _filter,
      accounts: accounts,
      countFor: (filter) =>
          items.where((item) => _matches(item, filter: filter)).length,
      onChanged: (filter) => setState(() => _filter = filter),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider(null));
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.navActivity),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
          final wide = constraints.maxWidth >= finoraWideContentWidth;
          final accounts =
              ref.watch(accountsProvider).value ?? const <FinancialAccount>[];
          final accountNames = {
            for (final account in accounts) account.id: account.name,
          };
          return FinoraPage(
          maxWidth: wide ? 1100 : 720,
          child: transactions.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(l10n.activityUnavailable)),
            data: (items) {
              final filtered = items.where(_matches).toList();
              final groups = <DateTime, List<FinancialTransaction>>{};
              for (final item in filtered) {
                final month = DateTime(item.bookedAt.year, item.bookedAt.month);
                groups.putIfAbsent(month, () => []).add(item);
              }
              return ListView(
                children: [
                  Text(
                    l10n.recentTransactionsSection,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.acrossAllAccounts,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  SearchBar(
                    leading: const Icon(Icons.search),
                    hintText: l10n.searchHint,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          () {
                            final totals = ActivityTotals.of(filtered);
                            return l10n.activityTotals(
                              filtered.length,
                              formatMoneyWhole(totals.moneyIn),
                              formatMoneyWhole(totals.moneyOut),
                            );
                          }(),
                          style: const TextStyle(
                            color: finoraMutedInk,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_filter.isEmpty)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => _openFilters(items, accounts),
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(l10n.filterButton),
                        )
                      else
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => _openFilters(items, accounts),
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(
                            l10n.filterButtonCount(_filter.activeCount),
                          ),
                        ),
                    ],
                  ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          items.isEmpty
                              ? l10n.noTransactionsYet
                              : _query.trim().isEmpty
                              ? l10n.filterNoMatch
                              : l10n.noTransactionsMatch(_query),
                          style: const TextStyle(color: finoraMutedInk),
                        ),
                      ),
                    ),
                  if (wide && filtered.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _TableHeader(),
                  ],
                  for (final entry in groups.entries) ...[
                    SectionTitle(formatMonthYear(entry.key)),
                    Card(
                      child: Column(
                        children: [
                          for (final (index, item) in entry.value.indexed)
                            if (wide) ...[
                              if (index > 0) const Divider(height: 1),
                              _TransactionRow(
                                transaction: item,
                                accountName: accountNames[item.accountId],
                              ),
                            ] else
                              TransactionTile(transaction: item),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: filtered.isEmpty
                        ? null
                        : () => _copyCsv(filtered),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: Text(l10n.copyAsCsv),
                  ),
                ],
              );
            },
          ),
          );
          },
        ),
      ),
    );
  }
}

const _dateWidth = 96.0;
const _categoryWidth = 170.0;
const _accountWidth = 200.0;
const _amountWidth = 130.0;

/// Column labels above the desktop transaction table.
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const style = TextStyle(
      color: finoraSlate,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
    );
    Text label(String text, {TextAlign? align}) =>
        Text(text.toUpperCase(), style: style, textAlign: align);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          SizedBox(width: _dateWidth, child: label(l10n.activityColDate)),
          Expanded(child: label(l10n.activityColMerchant)),
          SizedBox(
            width: _categoryWidth,
            child: label(l10n.activityColCategory),
          ),
          SizedBox(width: _accountWidth, child: label(l10n.activityColAccount)),
          SizedBox(
            width: _amountWidth,
            child: label(l10n.activityColAmount, align: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

/// One transaction as a table row, for wide screens.
class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, this.accountName});
  final FinancialTransaction transaction;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final positive = !transaction.amount.isNegative;
    const muted = TextStyle(color: finoraMutedInk, fontSize: 13);
    return InkWell(
      onTap: () => showCategorySheet(context, transaction),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: _dateWidth,
            child: Text(
              DateFormat.MMMd(l10n.localeName).format(transaction.bookedAt),
              style: muted.copyWith(fontFeatures: finoraTabular),
            ),
          ),
          Expanded(
            child: Text(
              transaction.merchant,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: finoraInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: _categoryWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ValuePill(
                label: l10n.transactionCategory(transaction.category),
                color: positive ? finoraGreen : finoraBlueText,
              ),
            ),
          ),
          SizedBox(
            width: _accountWidth,
            child: Text(
              accountName ?? transaction.accountId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
          SizedBox(
            width: _amountWidth,
            child: Text(
              formatMoney(transaction.amount, signed: true),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: positive ? finoraGreen : finoraInk,
                fontWeight: FontWeight.w700,
                fontFeatures: finoraTabular,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

String _csvField(String value) => value.contains(RegExp('[",\n]'))
    ? '"${value.replaceAll('"', '""')}"'
    : value;

/// Period, direction, categories and account for the activity list. Each
/// change applies at once.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.accounts,
    required this.countFor,
    required this.onChanged,
  });

  final TransactionFilter initial;
  final List<FinancialAccount> accounts;
  final int Function(TransactionFilter) countFor;
  final ValueChanged<TransactionFilter> onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionFilter _filter = widget.initial;

  void _set(TransactionFilter filter) {
    setState(() => _filter = filter);
    widget.onChanged(filter);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              l10n.filterButton,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            heading(l10n.filterPeriod),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (period, label) in [
                  (ActivityPeriod.all, l10n.filterPeriodAll),
                  (ActivityPeriod.thisMonth, l10n.filterPeriodThisMonth),
                  (ActivityPeriod.threeMonths, l10n.filterPeriodThreeMonths),
                  (ActivityPeriod.twelveMonths, l10n.filterPeriodTwelveMonths),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter.period == period,
                    onSelected: (_) => _set(_filter.copyWith(period: period)),
                  ),
              ],
            ),
            heading(l10n.filterDirection),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (direction, label) in [
                  (ActivityDirection.both, l10n.filterDirectionBoth),
                  (ActivityDirection.moneyIn, l10n.filterDirectionIn),
                  (ActivityDirection.moneyOut, l10n.filterDirectionOut),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter.direction == direction,
                    onSelected: (_) =>
                        _set(_filter.copyWith(direction: direction)),
                  ),
              ],
            ),
            heading(l10n.filterCategories),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in TransactionCategory.values)
                  FilterChip(
                    label: Text(l10n.transactionCategory(category)),
                    selected: _filter.categories.contains(category),
                    onSelected: (selected) => _set(
                      _filter.copyWith(
                        categories: selected
                            ? {..._filter.categories, category}
                            : {
                                for (final item in _filter.categories)
                                  if (item != category) item,
                              },
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.accounts.length > 1) ...[
              heading(l10n.filterAccount),
              DropdownButtonFormField<String?>(
                initialValue: _filter.accountId,
                isExpanded: true,
                items: [
                  DropdownMenuItem(child: Text(l10n.filterAllAccounts)),
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) =>
                    _set(_filter.copyWith(accountId: () => value)),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _filter.isEmpty
                      ? null
                      : () => _set(const TransactionFilter()),
                  child: Text(l10n.filterClear),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.filterShow(widget.countFor(_filter))),
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
