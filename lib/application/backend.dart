import 'dart:async';

import 'package:finora/application/calendar.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/backend_services.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/partners.dart';
import 'package:finora/domain/purchases.dart';
import 'package:finora/domain/trust.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final all = next.value;
      if (all == null) return;
      // Only what the user opted into; an empty list clears the server.
      final events = ref.read(sessionProvider).reminders.filter(all);
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

/// Where offers lead. The demo has no partner contracts.
final partnerDirectoryProvider = Provider<PartnerDirectory>(
  (ref) => const NoPartners(),
);

/// Partner links by offer kind; empty when they cannot be loaded, so an
/// offer then ends in the explanation instead of failing.
final partnerLinksProvider =
    FutureProvider<Map<OpportunityKind, PartnerLink>>((ref) async {
      try {
        return await ref.watch(partnerDirectoryProvider).links();
      } on Object {
        return const {};
      }
    });

/// Opens a partner link outside the app.
final linkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => DemoPurchaseService(ref.watch(clockProvider)),
);

/// Store prices by billing period; empty in the demo or when the store
/// cannot be reached.
final storePricesProvider = FutureProvider<Map<BillingPeriod, StorePrice>>((
  ref,
) async {
  try {
    return await ref.watch(purchaseServiceProvider).prices();
  } on Object {
    return const {};
  }
});

/// On store builds, checks once per start that a Premium subscription is
/// still active (it may have been cancelled or refunded in Google Play).
/// A failed check (offline) keeps Premium; only "nothing to restore" ends it.
final billingSyncProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(purchaseServiceProvider);
  if (!service.isStore) return;
  final session = ref.read(sessionProvider);
  if (!session.isPlus || session.onTrial) return;
  final result = await service.restore();
  if (result.status == PurchaseStatus.nothingToRestore) {
    ref.read(sessionProvider.notifier).cancelPlus();
  }
});

final notificationPermissionsProvider = Provider<NotificationPermissions>(
  (ref) => const DemoNotificationPermissions(),
);
