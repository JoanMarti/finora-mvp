import 'dart:convert';

import 'package:finora/domain/assets.dart';
import 'package:finora/domain/household.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/domain/trust.dart';

/// Everything Finora needs to remember about the user between launches.
class UserSession {
  const UserSession({
    this.email = '',
    this.products = const {},
    this.connectedInstitutionIds = const {},
    this.onboardingCompleted = false,
    this.dataHealthAlerts = true,
    this.languageCode,
    this.targets = const WealthTargets(),
    this.goals = const [],
    this.retirement,
    this.offersConsent,
    this.dismissedOpportunities = const {},
    this.plan = FinoraPlan.free,
    this.plusSince,
    this.consentLog = const [],
    this.funnel = const FunnelStats(),
    this.manualAssets = const [],
    this.hideAmounts = false,
    this.household,
    this.installationId,
  });

  /// A ready-to-explore profile used by "Use demo data instead" and tests.
  factory UserSession.demo() => UserSession(
    email: 'demo@finora.ch',
    products: FinancialProductType.values.toSet(),
    connectedInstitutionIds: InstitutionCatalogue.demoInstitutionIds,
    onboardingCompleted: true,
    goals: [
      SavingsGoal(
        id: 'demo-flat',
        name: 'Flat deposit',
        target: const Money.cents(4000000),
        deadline: DateTime(2028, 6),
        accountIds: const {'ubs-savings', 'zkb-savings'},
      ),
    ],
  );

  final String email;
  final Set<FinancialProductType> products;
  final Set<String> connectedInstitutionIds;
  final bool onboardingCompleted;
  final bool dataHealthAlerts;

  /// Preferred app language (`en`, `de`, `fr`, `it`); `null` follows the
  /// device.
  final String? languageCode;

  /// Wealth-plan targets the user can adjust.
  final WealthTargets targets;
  final List<SavingsGoal> goals;

  /// Pension details; `null` until the user fills them in.
  final RetirementProfile? retirement;

  /// Express consent to analyse account data for personalised savings
  /// offers (required for high-risk profiling under the revised FADP).
  /// `null` until the user has been asked.
  final bool? offersConsent;

  /// Opportunity ids the user marked as not interesting.
  final Set<String> dismissedOpportunities;

  final FinoraPlan plan;

  /// When the current Plus subscription started; `null` on the free plan.
  final DateTime? plusSince;

  /// Every consent answer, oldest first (revised FADP accountability).
  final List<ConsentRecord> consentLog;

  /// Aggregated offer funnel for the pilot metrics.
  final FunnelStats funnel;

  /// Property, vehicles, crypto and other assets entered by the user.
  final List<ManualAsset> manualAssets;

  /// Masks every amount so the app can be used in public.
  final bool hideAmounts;

  /// The partner's figures for the household view (Finora Plus).
  final Household? household;

  /// Random id for this installation, used only to key aggregated data
  /// sent to the backend. Created when a backend is first used.
  final String? installationId;

  bool get isPlus => plan == FinoraPlan.plus;

  static const _unset = Object();

  /// Display name derived from the e-mail, e.g. "anna.muster@…" → "Anna".
  /// `null` when there is no e-mail yet.
  String? get displayName {
    final local = email.split('@').first.split(RegExp(r'[._+-]')).first;
    if (local.isEmpty) return null;
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
    Object? languageCode = _unset,
    WealthTargets? targets,
    List<SavingsGoal>? goals,
    RetirementProfile? retirement,
    bool? offersConsent,
    Set<String>? dismissedOpportunities,
    FinoraPlan? plan,
    Object? plusSince = _unset,
    List<ConsentRecord>? consentLog,
    FunnelStats? funnel,
    List<ManualAsset>? manualAssets,
    bool? hideAmounts,
    Object? household = _unset,
    String? installationId,
  }) {
    return UserSession(
      email: email ?? this.email,
      products: products ?? this.products,
      connectedInstitutionIds:
          connectedInstitutionIds ?? this.connectedInstitutionIds,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      dataHealthAlerts: dataHealthAlerts ?? this.dataHealthAlerts,
      languageCode: identical(languageCode, _unset)
          ? this.languageCode
          : languageCode as String?,
      targets: targets ?? this.targets,
      goals: goals ?? this.goals,
      retirement: retirement ?? this.retirement,
      offersConsent: offersConsent ?? this.offersConsent,
      dismissedOpportunities:
          dismissedOpportunities ?? this.dismissedOpportunities,
      plan: plan ?? this.plan,
      plusSince: identical(plusSince, _unset)
          ? this.plusSince
          : plusSince as DateTime?,
      consentLog: consentLog ?? this.consentLog,
      funnel: funnel ?? this.funnel,
      manualAssets: manualAssets ?? this.manualAssets,
      hideAmounts: hideAmounts ?? this.hideAmounts,
      household: identical(household, _unset)
          ? this.household
          : household as Household?,
      installationId: installationId ?? this.installationId,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'email': email,
    'products': [for (final product in products) product.name],
    'connectedInstitutionIds': connectedInstitutionIds.toList(),
    'onboardingCompleted': onboardingCompleted,
    'dataHealthAlerts': dataHealthAlerts,
    'languageCode': languageCode,
    'targets': targets.toJson(),
    'goals': [for (final goal in goals) goal.toJson()],
    'retirement': retirement?.toJson(),
    'offersConsent': offersConsent,
    'dismissedOpportunities': dismissedOpportunities.toList(),
    'plan': plan.name,
    'plusSince': plusSince?.toIso8601String(),
    'consentLog': [for (final record in consentLog) record.toJson()],
    'funnel': funnel.toJson(),
    'manualAssets': [for (final asset in manualAssets) asset.toJson()],
    'hideAmounts': hideAmounts,
    'household': household?.toJson(),
    'installationId': installationId,
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
      languageCode: json['languageCode'] as String?,
      targets: json['targets'] is Map
          ? WealthTargets.fromJson(
              (json['targets']! as Map).cast<String, Object?>(),
            )
          : const WealthTargets(),
      goals: [
        for (final raw in (json['goals'] as List?) ?? const [])
          ?SavingsGoal.fromJson(raw),
      ],
      retirement: RetirementProfile.fromJson(json['retirement']),
      offersConsent: json['offersConsent'] as bool?,
      dismissedOpportunities: {
        ...?(json['dismissedOpportunities'] as List?)?.whereType<String>(),
      },
      plan: FinoraPlan.values
              .where((value) => value.name == json['plan'])
              .firstOrNull ??
          FinoraPlan.free,
      plusSince: DateTime.tryParse('${json['plusSince']}'),
      consentLog: [
        for (final raw in (json['consentLog'] as List?) ?? const [])
          ?ConsentRecord.fromJson(raw),
      ],
      funnel: FunnelStats.fromJson(json['funnel']),
      manualAssets: [
        for (final raw in (json['manualAssets'] as List?) ?? const [])
          ?ManualAsset.fromJson(raw),
      ],
      hideAmounts: json['hideAmounts'] as bool? ?? false,
      household: Household.fromJson(json['household']),
      installationId: json['installationId'] as String?,
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
