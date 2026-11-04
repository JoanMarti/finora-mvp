import 'package:finora/app/theme.dart';
import 'package:finora/application/backup.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/backup.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Saves everything Finora keeps on this device to a file, and restores it
/// on another phone.
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final now = ref.read(clockProvider)();
    try {
      await ref
          .read(backupFilesProvider)
          .save(
            FinoraBackup.encode(ref.read(sessionProvider), now: now),
            FinoraBackup.fileName(now),
          );
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupSaveFailed)));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final String? text;
    try {
      text = await ref.read(backupFilesProvider).pick();
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.backupProblemDamaged)),
      );
      return;
    }
    if (text == null || !context.mounted) return;
    final RestoredBackup backup;
    try {
      backup = FinoraBackup.decode(text, current: ref.read(sessionProvider));
    } on BackupFormatException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (error.problem) {
            BackupProblem.notABackup => l10n.backupProblemNotBackup,
            BackupProblem.newerVersion => l10n.backupProblemNewer,
            BackupProblem.damaged => l10n.backupProblemDamaged,
          }),
        ),
      );
      return;
    }
    final date = backup.exportedAt == null
        ? '–'
        : DateFormat.yMMMd(l10n.localeName).format(backup.exportedAt!);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.backupRestoreTitle),
        content: Text(dialogContext.l10n.backupRestoreBody(date)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.backupRestoreConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(sessionProvider.notifier).restore(backup.session);
    messenger.showSnackBar(SnackBar(content: Text(l10n.backupRestored)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.backupTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            Text(l10n.backupIntro, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _save(context, ref),
              icon: const Icon(Icons.save_alt),
              label: Text(l10n.backupExport),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _restore(context, ref),
              icon: const Icon(Icons.restore),
              label: Text(l10n.backupRestore),
            ),
            const SizedBox(height: 20),
            Card(
              color: finoraSoftBlue,
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: finoraBlueText),
                title: Text(l10n.backupWarning),
                subtitle: Text(l10n.backupKeeps),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
