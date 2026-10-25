import 'package:finora/app/layout.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
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

  bool _matches(FinancialTransaction item) {
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
          final accountNames = {
            for (final account
                in ref.watch(accountsProvider).value ?? const <FinancialAccount>[])
              account.id: account.name,
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
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          items.isEmpty
                              ? l10n.noTransactionsYet
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
    return Padding(
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
    );
  }
}

String _csvField(String value) => value.contains(RegExp('[",\n]'))
    ? '"${value.replaceAll('"', '""')}"'
    : value;
