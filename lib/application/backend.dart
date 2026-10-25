import 'dart:async';

import 'package:finora/application/calendar.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/backend_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a Finora backend is configured. `false` in the demo.
final backendEnabledProvider = Provider<bool>((ref) => false);

final funnelReporterProvider = Provider<FunnelReporter>(
  (ref) => const NoBackend(),
);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => const NoBackend(),
);

/// Keeps the backend in step with the device: reminders whenever the
/// calendar changes and the funnel whenever its counts change. Both calls
/// send the full state, so a failed call is simply repeated on the next
/// change. `FinoraApp` keeps this provider alive.
final backendSyncProvider = Provider<void>((ref) {
  if (!ref.watch(backendEnabledProvider)) return;

  Future<void> quietly(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // Offline or server error: the next change sends everything again.
    }
  }

  String installationId() =>
      ref.read(sessionProvider.notifier).ensureInstallationId();

  ref
    ..listen(calendarProvider, (_, next) {
      final events = next.value;
      if (events == null) return;
      final language = ref.read(sessionProvider).languageCode ?? 'en';
      unawaited(
        quietly(
          () => ref
            .read(reminderServiceProvider)
              .syncReminders(installationId(), events, languageCode: language),
        ),
      );
    }, fireImmediately: true)
    ..listen(funnelProvider, (_, next) {
      unawaited(
        quietly(
          () => ref.read(funnelReporterProvider).report(installationId(), next),
        ),
      );
    });
});
