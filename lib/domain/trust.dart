import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';

// -----------------------------------------------------------------------------
// Finora Plus
// -----------------------------------------------------------------------------

enum FinoraPlan { free, plus }

/// What Finora Plus adds. Everyday analysis never moves behind the paywall:
/// Plus only adds deeper planning and exports.
enum PlusFeature { retirementScenarios, taxExport, household }

/// Price shown on the Plus screen. CHF 59 a year is the business-plan
/// assumption and still has to be validated with users.
abstract final class PlusPricing {
  static const yearly = Money.cents(5900);
}

// -----------------------------------------------------------------------------
// Consent register
// -----------------------------------------------------------------------------

enum ConsentPurpose {
  /// Analysing account data for personalised savings offers (high-risk
  /// profiling under the revised FADP, so it needs express consent).
  offersAnalysis,

  /// Passing name, e-mail and the figures behind one offer to one partner.
  partnerSharing,
}

/// One answer the user gave, kept so Finora can show (and prove) what was
/// agreed, when, and to which version of the text.
class ConsentRecord {
  const ConsentRecord({
    required this.purpose,
    required this.granted,
    required this.at,
    this.textVersion = ConsentRecord.currentTextVersion,
    this.subject,
  });

  /// Bump whenever a consent text changes in a way that needs a new answer.
  static const currentTextVersion = '2026-10';

  final ConsentPurpose purpose;
  final bool granted;
  final DateTime at;
  final String textVersion;

  /// For partner sharing: the offer kind (`OpportunityKind.name`).
  final String? subject;

  OpportunityKind? get offerKind => subject == null
      ? null
      : OpportunityKind.values.where((kind) => kind.name == subject).firstOrNull;

  Map<String, Object?> toJson() => {
    'purpose': purpose.name,
    'granted': granted,
    'at': at.toIso8601String(),
    'textVersion': textVersion,
    if (subject != null) 'subject': subject,
  };

  static ConsentRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final purpose = ConsentPurpose.values
        .where((value) => value.name == raw['purpose'])
        .firstOrNull;
    final at = DateTime.tryParse('${raw['at']}');
    final granted = raw['granted'];
    if (purpose == null || at == null || granted is! bool) return null;
    return ConsentRecord(
      purpose: purpose,
      granted: granted,
      at: at,
      textVersion: raw['textVersion'] as String? ?? currentTextVersion,
      subject: raw['subject'] as String?,
    );
  }
}

// -----------------------------------------------------------------------------
// Offer funnel
// -----------------------------------------------------------------------------

enum OfferEventType { viewed, partnerClicked, dismissed }

/// Aggregated offer funnel. Holds counts per offer kind and the savings the
/// user chose to pursue; no names, amounts per person or timestamps, so it
/// can be reported to the business without personal data.
class FunnelStats {
  const FunnelStats({
    this.counts = const {},
    this.pursuedSavingLow = Money.zero,
    this.pursuedSavingHigh = Money.zero,
  });

  /// `kind.name` → event type → count.
  final Map<String, Map<OfferEventType, int>> counts;

  /// Sum of the estimated yearly saving of offers the user followed up.
  final Money pursuedSavingLow;
  final Money pursuedSavingHigh;

  bool get isEmpty => counts.isEmpty;

  int count(OfferEventType type, {OpportunityKind? kind}) {
    if (kind != null) return counts[kind.name]?[type] ?? 0;
    return counts.values.fold(0, (sum, byType) => sum + (byType[type] ?? 0));
  }

  /// Share of opened offers that led to a partner click (0 when none).
  double get clickRate => _rate(OfferEventType.partnerClicked);
  double get dismissRate => _rate(OfferEventType.dismissed);

  double _rate(OfferEventType type) {
    final views = count(OfferEventType.viewed);
    return views == 0 ? 0 : count(type) / views;
  }

  /// Offer kinds that have at least one event, most viewed first.
  List<OpportunityKind> get kinds {
    final found = [
      for (final kind in OpportunityKind.values)
        if (counts.containsKey(kind.name)) kind,
    ];
    found.sort(
      (a, b) => count(OfferEventType.viewed, kind: b)
          .compareTo(count(OfferEventType.viewed, kind: a)),
    );
    return found;
  }

  FunnelStats record(Opportunity opportunity, OfferEventType type) {
    final byType = {...?counts[opportunity.id]};
    byType[type] = (byType[type] ?? 0) + 1;
    final pursued = type == OfferEventType.partnerClicked;
    return FunnelStats(
      counts: {...counts, opportunity.id: byType},
      pursuedSavingLow: pursued
          ? pursuedSavingLow + (opportunity.savingLow ?? Money.zero)
          : pursuedSavingLow,
      pursuedSavingHigh: pursued
          ? pursuedSavingHigh + (opportunity.savingHigh ?? Money.zero)
          : pursuedSavingHigh,
    );
  }

  Map<String, Object?> toJson() => {
    'counts': {
      for (final entry in counts.entries)
        entry.key: {
          for (final byType in entry.value.entries) byType.key.name: byType.value,
        },
    },
    'pursuedSavingLow': pursuedSavingLow.cents,
    'pursuedSavingHigh': pursuedSavingHigh.cents,
  };

  static FunnelStats fromJson(Object? raw) {
    if (raw is! Map) return const FunnelStats();
    final counts = <String, Map<OfferEventType, int>>{};
    final rawCounts = raw['counts'];
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final byType = <OfferEventType, int>{};
        final value = entry.value;
        if (value is! Map) continue;
        for (final type in OfferEventType.values) {
          final count = value[type.name];
          if (count is int && count > 0) byType[type] = count;
        }
        if (byType.isNotEmpty) counts['${entry.key}'] = byType;
      }
    }
    int cents(Object? value) => value is int ? value : 0;
    return FunnelStats(
      counts: counts,
      pursuedSavingLow: Money.cents(cents(raw['pursuedSavingLow'])),
      pursuedSavingHigh: Money.cents(cents(raw['pursuedSavingHigh'])),
    );
  }
}
