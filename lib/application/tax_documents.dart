import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/tax_documents.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Papers for the tax return being prepared.
final taxDocumentChecklistProvider = FutureProvider<TaxDocumentChecklist>((
  ref,
) async {
  final accounts = await ref.watch(accountsProvider.future);
  final session = ref.watch(sessionProvider);
  return TaxDocumentChecklist.build(
    now: ref.watch(clockProvider)(),
    accounts: accounts,
    profile: session.profile,
    manualAssets: session.manualAssets,
    hasLoans: (session.debts ?? const []).isNotEmpty,
  );
});
