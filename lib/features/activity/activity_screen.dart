import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        child: FinoraPage(
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
                  for (final entry in groups.entries) ...[
                    SectionTitle(formatMonthYear(entry.key)),
                    Card(
                      child: Column(
                        children: [
                          for (final item in entry.value)
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
        ),
      ),
    );
  }
}

String _csvField(String value) => value.contains(RegExp('[",\n]'))
    ? '"${value.replaceAll('"', '""')}"'
    : value;
