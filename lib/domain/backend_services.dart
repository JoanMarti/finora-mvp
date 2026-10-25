import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/trust.dart';

/// Sends the aggregated offer funnel to the business analytics. Only
/// counts per offer type and saving ranges leave the device, keyed by an
/// anonymous installation id.
abstract interface class FunnelReporter {
  Future<void> report(String installationId, FunnelStats stats);
}

/// Push reminders for the financial calendar. The backend owns the device
/// token and sends the notifications; the app tells it which dated events
/// exist (kind and date only, no amounts or names).
abstract interface class ReminderService {
  Future<void> syncReminders(
    String installationId,
    List<CalendarEvent> events, {
    required String languageCode,
  });
}

/// Used in the demo and whenever no backend is configured.
class NoBackend implements FunnelReporter, ReminderService {
  const NoBackend();

  @override
  Future<void> report(String installationId, FunnelStats stats) async {}

  @override
  Future<void> syncReminders(
    String installationId,
    List<CalendarEvent> events, {
    required String languageCode,
  }) async {}
}
