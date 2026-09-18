import 'package:finora/data/mock_financial_repository.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            data: (items) => ListView(
              children: [
                Text(
                  'Recent transactions',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Across all connected cash accounts',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                const SearchBar(
                  leading: Icon(Icons.search),
                  hintText: 'Search transactions',
                ),
                const SectionTitle('September'),
                Card(
                  child: Column(
                    children: [
                      for (final item in items)
                        TransactionTile(transaction: item),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export CSV · Plus'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
