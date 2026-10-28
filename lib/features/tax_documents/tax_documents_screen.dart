import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/application/tax_documents.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/tax_documents.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The papers to collect for the tax return, ticked off as they arrive.
class TaxDocumentsScreen extends ConsumerWidget {
  const TaxDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final checklist = ref.watch(taxDocumentChecklistProvider).value;
    final ready = ref.watch(
      sessionProvider.select((session) => session.taxDocumentsReady),
    );
    final institutions =
        ref.watch(institutionsProvider).value ?? const <Institution>[];
    String institutionName(String? id) =>
        institutions.where((item) => item.id == id).firstOrNull?.name ??
        id ??
        '';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.taxDocsTitle),
      ),
      body: FinoraPage(
        child: checklist == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  _ProgressCard(checklist: checklist, ready: ready),
                  const SizedBox(height: 12),
                  Text(
                    l10n.taxDocsIntro,
                    style: const TextStyle(color: finoraMutedInk),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        for (final document in checklist.documents)
                          CheckboxListTile(
                            value: ready.contains(checklist.keyOf(document)),
                            onChanged: (value) => ref
                                .read(sessionProvider.notifier)
                                .setTaxDocumentReady(
                                  checklist.keyOf(document),
                                  ready: value ?? false,
                                ),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              l10n.taxDocumentTitle(
                                document,
                                institutionName(document.institutionId),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              document.optional
                                  ? '${l10n.taxDocsOptional} · '
                                        '${l10n.taxDocumentHint(document.kind)}'
                                  : l10n.taxDocumentHint(document.kind),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.checklist, required this.ready});
  final TaxDocumentChecklist checklist;
  final Set<String> ready;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = checklist.progress(ready);
    return HeroCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.taxDocsHeading(checklist.taxYear),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(finoraRadiusSmall),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress >= 1
                  ? l10n.taxDocsAllReady
                  : l10n.taxDocsProgress(
                      checklist.readyCount(ready),
                      checklist.documents.length,
                    ),
              style: const TextStyle(color: finoraSilver),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.taxDocsDeadline(
                DateFormat.yMMMd(l10n.localeName).format(checklist.deadline),
              ),
              style: const TextStyle(color: finoraSilver, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Link to the checklist, with how many papers are ready.
class TaxDocumentsLinkCard extends ConsumerWidget {
  const TaxDocumentsLinkCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final checklist = ref.watch(taxDocumentChecklistProvider).value;
    if (checklist == null) return const SizedBox.shrink();
    final ready = ref.watch(
      sessionProvider.select((session) => session.taxDocumentsReady),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const TonalIcon(Icons.fact_check_outlined, size: 40),
        title: Text(
          l10n.taxDocsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          l10n.taxDocsCardBody(
            checklist.readyCount(ready),
            checklist.documents.length,
            checklist.taxYear,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/tax-documents'),
      ),
    );
  }
}
