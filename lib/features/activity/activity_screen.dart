import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
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
        item.category.label.toLowerCase().contains(query);
  }

  Future<void> _copyCsv(List<FinancialTransaction> items) async {
    final rows = [
      'date,merchant,category,amount,currency,account',
      for (final item in items)
        [
          item.bookedAt.toIso8601String().substring(0, 10),
          _csvField(item.merchant),
          item.category.label,
          item.amount.amount.toStringAsFixed(2),
          item.amount.currency,
          item.accountId,
        ].join(','),
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${items.length} transactions copied as CSV.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider(null));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Activity'),
      ),
      body: SafeArea(
        top: false,
        child: FinoraPage(
          child: transactions.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: Text('Activity is temporarily unavailable.'),
            ),
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
                    'Recent transactions',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Across all connected accounts',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  SearchBar(
                    leading: const Icon(Icons.search),
                    hintText: 'Search merchant or category',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          items.isEmpty
                              ? 'No transactions yet.'
                              : 'No transactions match "$_query".',
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
                    label: const Text('Copy as CSV'),
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
