import 'package:finora/domain/opportunities.dart';

/// Where an offer leads once the user agrees to continue: the partner's
/// name and the tracked link. Links come from configuration (the backend's
/// `GET /v1/partners`), never from the app code, so partners and affiliate
/// ids can change without a release.
class PartnerLink {
  const PartnerLink({
    required this.kind,
    required this.partnerName,
    required this.url,
  });

  final OpportunityKind kind;
  final String partnerName;

  /// Affiliate or lead link as configured, including the network's ids.
  final Uri url;

  /// The link with Finora's own campaign parameters added. Personal data
  /// is never put in a link: only the offer kind.
  Uri trackedUrl() => url.replace(
    queryParameters: {
      ...url.queryParameters,
      'utm_source': 'finora',
      'utm_medium': 'app',
      'utm_campaign': kind.name,
    },
  );

  static PartnerLink? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = OpportunityKind.values
        .where((value) => value.name == raw['kind'])
        .firstOrNull;
    final name = raw['partnerName'];
    final url = Uri.tryParse('${raw['url']}');
    if (kind == null || name is! String || name.isEmpty) return null;
    if (url == null || url.scheme != 'https') return null;
    return PartnerLink(kind: kind, partnerName: name, url: url);
  }
}

/// Source of partner links, keyed by offer kind.
abstract interface class PartnerDirectory {
  Future<Map<OpportunityKind, PartnerLink>> links();
}

/// Demo: no partner contracts yet, so offers end in an explanation.
class NoPartners implements PartnerDirectory {
  const NoPartners();

  @override
  Future<Map<OpportunityKind, PartnerLink>> links() async => const {};
}
