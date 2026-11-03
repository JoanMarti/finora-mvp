import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets the user pick a statement file; returns its text, or `null` when
/// the picker was closed.
abstract interface class StatementFilePicker {
  Future<String?> pick();
}

class SystemStatementFilePicker implements StatementFilePicker {
  const SystemStatementFilePicker();

  static const _types = XTypeGroup(
    label: 'CSV',
    extensions: ['csv', 'txt'],
    mimeTypes: [
      'text/csv',
      'text/comma-separated-values',
      'text/plain',
      'application/vnd.ms-excel',
    ],
    uniformTypeIdentifiers: [
      'public.comma-separated-values-text',
      'public.plain-text',
    ],
  );

  @override
  Future<String?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_types]);
    if (file == null) return null;
    return decodeStatement(await file.readAsBytes());
  }
}

/// UTF-8 when the bytes are valid UTF-8, else Windows Latin-1, which many
/// Swiss banks still export.
String decodeStatement(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

final statementFilePickerProvider = Provider<StatementFilePicker>(
  (ref) => const SystemStatementFilePicker(),
);
