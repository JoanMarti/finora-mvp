import 'dart:convert';

import 'package:finora/app/theme.dart';
import 'package:finora/application/backup.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/app_lock.dart';
import 'package:finora/domain/backup.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/backup/backup_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime(2026, 11, 4, 22);

final _source = UserSession.demo().copyWith(
  installationId: 'old-phone',
  appLock: const AppLock(salt: 'old', pinHash: 'old-hash'),
  budgets: {TransactionCategory.dining: const Money.cents(30000)},
  taxDocumentsReady: {'2026:salaryCertificate'},
  plan: FinoraPlan.plus,
  trialUsed: true,
);

class _FakeFiles implements BackupFiles {
  _FakeFiles([this.toPick]);
  final String? toPick;
  final saved = <(String, String)>[];

  @override
  Future<void> save(String content, String fileName) async =>
      saved.add((content, fileName));

  @override
  Future<String?> pick() async => toPick;
}

void main() {
  group('Backup', () {
    test('the file holds the data but not the PIN or the device id', () {
      final text = FinoraBackup.encode(_source, now: _now);
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['format'], 'finora-backup');
      expect(json['version'], 1);
      final session = json['session']! as Map<String, Object?>;
      expect(session['appLock'], isNull);
      expect(session.containsKey('installationId'), isFalse);
      expect(FinoraBackup.fileName(_now), 'finora-backup-2026-11-04.json');
    });

    test('restoring keeps the data and this device\'s PIN and plan', () {
      final text = FinoraBackup.encode(_source, now: _now);
      final current = UserSession.demo().copyWith(
        installationId: 'new-phone',
        appLock: const AppLock(salt: 'new', pinHash: 'new-hash'),
      );
      final restored = FinoraBackup.decode(text, current: current);
      expect(restored.exportedAt, _now);
      final session = restored.session;
      expect(
        session.budgets[TransactionCategory.dining],
        const Money.cents(30000),
      );
      expect(session.taxDocumentsReady, {'2026:salaryCertificate'});
      expect(session.goals.length, _source.goals.length);
      expect(session.appLock?.pinHash, 'new-hash');
      expect(session.installationId, 'new-phone');
      // Premium comes from the store, not from a file; a used trial stays
      // used.
      expect(session.plan, current.plan);
      expect(session.trialUsed, isTrue);
    });

    test('other files are refused with a reason', () {
      Matcher problem(BackupProblem value) => throwsA(
        isA<BackupFormatException>().having(
          (error) => error.problem,
          'problem',
          value,
        ),
      );
      final current = UserSession.demo();
      expect(
        () => FinoraBackup.decode('Datum;Betrag', current: current),
        problem(BackupProblem.notABackup),
      );
      expect(
        () => FinoraBackup.decode('{"format":"other"}', current: current),
        problem(BackupProblem.notABackup),
      );
      expect(
        () => FinoraBackup.decode(
          '{"format":"finora-backup","version":99,"session":{}}',
          current: current,
        ),
        problem(BackupProblem.newerVersion),
      );
      expect(
        () => FinoraBackup.decode(
          '{"format":"finora-backup","version":1,"session":[]}',
          current: current,
        ),
        problem(BackupProblem.damaged),
      );
    });
  });

  Widget app(ProviderContainer container) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: buildFinoraTheme(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const BackupScreen(),
    ),
  );

  testWidgets('saving hands the file over', (tester) async {
    usePhoneViewport(tester);
    final files = _FakeFiles();
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(session: _source),
        backupFilesProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save a backup'));
    await tester.pumpAndSettle();
    expect(files.saved.single.$2, startsWith('finora-backup-'));
    expect(files.saved.single.$1, contains('"format": "finora-backup"'));
  });

  testWidgets('restoring asks first, then replaces the data', (tester) async {
    usePhoneViewport(tester);
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(session: UserSession.demo()),
        backupFilesProvider.overrideWithValue(
          _FakeFiles(FinoraBackup.encode(_source, now: _now)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    expect(find.text('Replace the data on this device?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(
      container.read(sessionProvider).taxDocumentsReady,
      {'2026:salaryCertificate'},
    );
    expect(find.text('Backup restored.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
