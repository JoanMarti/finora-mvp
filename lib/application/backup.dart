import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:finora/application/statement_import.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a backup file to the user and picks one to restore.
abstract interface class BackupFiles {
  /// The system share sheet on Android, a download on the web.
  Future<void> save(String content, String fileName);

  /// The chosen file's text, or `null` when the picker was closed.
  Future<String?> pick();
}

class SystemBackupFiles implements BackupFiles {
  const SystemBackupFiles();

  static const _types = XTypeGroup(
    label: 'Finora backup',
    extensions: ['json'],
    mimeTypes: ['application/json', 'text/plain', 'application/octet-stream'],
    uniformTypeIdentifiers: ['public.json'],
  );

  @override
  Future<void> save(String content, String fileName) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(content)),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }

  @override
  Future<String?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_types]);
    if (file == null) return null;
    return decodeStatement(await file.readAsBytes());
  }
}

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => const SystemBackupFiles(),
);
