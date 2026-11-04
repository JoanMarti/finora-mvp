import 'dart:convert';

import 'package:finora/domain/user_session.dart';

/// Why a file could not be restored.
enum BackupProblem { notABackup, newerVersion, damaged }

class BackupFormatException implements Exception {
  const BackupFormatException(this.problem);
  final BackupProblem problem;

  @override
  String toString() => 'BackupFormatException(${problem.name})';
}

/// A copy of everything Finora keeps on this device (goals, budgets,
/// profile, imported statements, settings…), to move to a new phone. App
/// data is not part of cloud backups, so this is the way to keep it.
abstract final class FinoraBackup {
  static const format = 'finora-backup';
  static const version = 1;

  /// The file's content. The PIN and the anonymous installation id stay on
  /// this device.
  static String encode(UserSession session, {required DateTime now}) =>
      const JsonEncoder.withIndent('  ').convert({
        'format': format,
        'version': version,
        'exportedAt': now.toIso8601String(),
        'session': session.copyWith(appLock: null).toJson()
          ..remove('installationId'),
      });

  static String fileName(DateTime now) =>
      'finora-backup-${now.toIso8601String().substring(0, 10)}.json';

  /// Reads a backup into a session for this device. What belongs to the
  /// device or to the store stays as it is: the PIN, the installation id
  /// and the plan (Premium comes from the purchase, not from a file).
  static RestoredBackup decode(String text, {required UserSession current}) {
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException {
      throw const BackupFormatException(BackupProblem.notABackup);
    }
    if (raw is! Map || raw['format'] != format) {
      throw const BackupFormatException(BackupProblem.notABackup);
    }
    final fileVersion = raw['version'];
    if (fileVersion is! int || fileVersion > version) {
      throw const BackupFormatException(BackupProblem.newerVersion);
    }
    final session = raw['session'];
    if (session is! Map) {
      throw const BackupFormatException(BackupProblem.damaged);
    }
    final UserSession restored;
    try {
      restored = UserSession.fromJson(session.cast<String, Object?>());
    } on Object {
      throw const BackupFormatException(BackupProblem.damaged);
    }
    final prepared = restored.copyWith(
      appLock: current.appLock,
      installationId: current.installationId,
      plan: current.plan,
      plusSince: current.plusSince,
      trialEndsAt: current.trialEndsAt,
      trialUsed: current.trialUsed || restored.trialUsed,
      billingPeriod: current.billingPeriod,
      languageCode: current.languageCode ?? restored.languageCode,
    );
    return RestoredBackup(
      session: prepared,
      exportedAt: DateTime.tryParse('${raw['exportedAt']}'),
    );
  }
}

/// A backup read from a file, ready to replace the data on this device.
class RestoredBackup {
  const RestoredBackup({required this.session, this.exportedAt});

  final UserSession session;
  final DateTime? exportedAt;
}
