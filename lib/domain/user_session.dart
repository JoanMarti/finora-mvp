import 'dart:convert';

import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';

/// Everything Finora needs to remember about the user between launches.
class UserSession {
  const UserSession({
    this.email = '',
    this.products = const {},
    this.connectedInstitutionIds = const {},
    this.onboardingCompleted = false,
    this.dataHealthAlerts = true,
  });

  /// A ready-to-explore profile used by "Use demo data instead" and tests.
  factory UserSession.demo() => UserSession(
    email: 'demo@finora.ch',
    products: FinancialProductType.values.toSet(),
    connectedInstitutionIds: InstitutionCatalogue.demoInstitutionIds,
    onboardingCompleted: true,
  );

  final String email;
  final Set<FinancialProductType> products;
  final Set<String> connectedInstitutionIds;
  final bool onboardingCompleted;
  final bool dataHealthAlerts;

  /// Display name derived from the e-mail, e.g. "anna.muster@…" → "Anna".
  String get displayName {
    final local = email.split('@').first.split(RegExp(r'[._+-]')).first;
    if (local.isEmpty) return 'You';
    return local[0].toUpperCase() + local.substring(1);
  }

  String get initials {
    final parts = email
        .split('@')
        .first
        .split(RegExp(r'[._+-]'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  UserSession copyWith({
    String? email,
    Set<FinancialProductType>? products,
    Set<String>? connectedInstitutionIds,
    bool? onboardingCompleted,
    bool? dataHealthAlerts,
  }) {
    return UserSession(
      email: email ?? this.email,
      products: products ?? this.products,
      connectedInstitutionIds:
          connectedInstitutionIds ?? this.connectedInstitutionIds,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      dataHealthAlerts: dataHealthAlerts ?? this.dataHealthAlerts,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'email': email,
    'products': [for (final product in products) product.name],
    'connectedInstitutionIds': connectedInstitutionIds.toList(),
    'onboardingCompleted': onboardingCompleted,
    'dataHealthAlerts': dataHealthAlerts,
  };

  static UserSession fromJson(Map<String, Object?> json) {
    final productNames = (json['products'] as List?)?.whereType<String>() ??
        const <String>[];
    final institutionIds =
        (json['connectedInstitutionIds'] as List?)?.whereType<String>() ??
        const <String>[];
    return UserSession(
      email: json['email'] as String? ?? '',
      products: {
        for (final name in productNames)
          ...FinancialProductType.values.where((type) => type.name == name),
      },
      connectedInstitutionIds: institutionIds
          .where((id) => InstitutionCatalogue.byId(id) != null)
          .toSet(),
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      dataHealthAlerts: json['dataHealthAlerts'] as bool? ?? true,
    );
  }

  String encode() => jsonEncode(toJson());

  /// Returns `null` when [raw] is missing or unreadable, so a corrupt value
  /// never blocks the app from starting.
  static UserSession? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      return fromJson(json);
    } catch (_) {
      return null;
    }
  }
}

/// Persistence boundary for [UserSession]. Implementations must be able to
/// load synchronously so the router can decide the first screen immediately.
abstract interface class SessionStore {
  UserSession? load();
  Future<void> save(UserSession session);
  Future<void> clear();
}

class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this._session]);
  UserSession? _session;

  @override
  UserSession? load() => _session;

  @override
  Future<void> save(UserSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
