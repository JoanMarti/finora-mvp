import 'package:finora/data/api/api_client.dart';
import 'package:finora/domain/backend_services.dart';
import 'package:finora/domain/calendar.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/partners.dart';
import 'package:finora/domain/trust.dart';

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Stable, non-reversible tag for a goal or asset name (32-bit FNV-1a), so
/// reminder ids stay unique without sending the name itself.
String _tag(String? value) {
  if (value == null || value.isEmpty) return '0';
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16);
}

/// [FunnelReporter] and [ReminderService] over the Finora backend. Both
/// calls are idempotent `PUT`s of the full current state, so retrying or
/// sending twice is harmless.
class HttpBackendServices
    implements FunnelReporter, ReminderService, PartnerDirectory {
  HttpBackendServices(this._api);

  final FinoraApiClient _api;

  @override
  Future<void> report(String installationId, FunnelStats stats) async {
    await _api.put(
      'v1/installations/$installationId/funnel',
      stats.toJson(),
    );
  }

  @override
  Future<void> syncReminders(
    String installationId,
    List<CalendarEvent> events, {
    required String languageCode,
  }) async {
    await _api.put('v1/installations/$installationId/reminders', {
      'language': languageCode,
      'reminders': [
        for (final event in events.where((event) => event.kind.exportable))
          {
            'id': '${event.kind.name}-${_day(event.date)}-${_tag(event.subject)}',
            'kind': event.kind.name,
            'date': _day(event.date),
          },
      ],
    });
  }

  /// Partner links as configured on the server; invalid entries are left
  /// out so one bad row never hides the others.
  @override
  Future<Map<OpportunityKind, PartnerLink>> links() async {
    final body = await _api.get('v1/partners');
    final links = <OpportunityKind, PartnerLink>{};
    if (body is List) {
      for (final link in body.map(PartnerLink.fromJson).nonNulls) {
        links[link.kind] = link;
      }
    }
    return links;
  }

  /// Asks the server whether a Google Play purchase token is valid and the
  /// subscription active; the server checks it with the Play Developer API.
  Future<bool> verifyPurchase(String receipt) async {
    final body = await _api.post('v1/purchases/verify', {
      'platform': 'android',
      'receipt': receipt,
    });
    return body is Map && body['active'] == true;
  }
}
