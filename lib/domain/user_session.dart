import 'dart:convert';

import 'package:finora/domain/app_lock.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/domain/budgets.dart';
import 'package:finora/domain/debts.dart';
import 'package:finora/domain/household.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/domain/reminders.dart';
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
    this.appLock,
    this.reminders = const ReminderPreferences(),
    this.budgets = const {},
    this.subscriptionDecisions = const {},
    this.debts,
    this.debtPayment,
    this.payoffStrategy = PayoffStrategy.avalanche,
    this.firstName,
    this.userId,
    this.emailVerified = false,
    this.marketingOptIn = false,
    this.trialEndsAt,
    this.trialUsed = false,
    this.billingPeriod,
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

  /// PIN lock; `null` when the app is not locked.
  final AppLock? appLock;

  /// Push reminder choices for the financial calendar.
  final ReminderPreferences reminders;

  /// Monthly spending limit per category.
  final Map<TransactionCategory, Money> budgets;

  /// The user's decision per subscription, keyed by merchant.
  final Map<String, SubscriptionDecision> subscriptionDecisions;

  /// Debts in the payoff plan; `null` until the plan is first opened, when
  /// it starts from the connected credit cards.
  final List<Debt>? debts;

  /// Monthly amount for repaying debts; `null` uses the minimums plus 10 %.
  final Money? debtPayment;
  final PayoffStrategy payoffStrategy;

  /// Name given at sign-up; `null` for demo profiles and older sessions.
  final String? firstName;

  /// Account id from the [AuthService]; `null` until the user registers or
  /// signs in (demo profiles have none).
  final String? userId;

  /// Whether the e-mail address was confirmed with the code sent to it.
  final bool emailVerified;

  /// Optional product news by e-mail, asked separately from the terms.
  final bool marketingOptIn;

  bool get hasAccount => userId != null;

  /// End of the Premium trial; `null` when no trial is running.
  final DateTime? trialEndsAt;

  /// The trial is offered once per profile.
  final bool trialUsed;

  /// How a paid Premium subscription is billed; `null` on Free or trial.
  final BillingPeriod? billingPeriod;

  /// Whether the session holds Premium, ignoring trial expiry. Use
  /// [isPremiumAt] (or `isPlusProvider`) to decide what to unlock.
  bool get isPlus => plan == FinoraPlan.plus;

  bool get onTrial => isPlus && trialEndsAt != null;

  bool isPremiumAt(DateTime now) =>
      isPlus && (trialEndsAt == null || now.isBefore(trialEndsAt!));

  static const _unset = Object();

  /// Display name derived from the e-mail, e.g. "anna.muster@…" → "Anna".
  /// `null` when there is no e-mail yet.
  String? get displayName {
    final name = firstName?.trim() ?? '';
    if (name.isNotEmpty) return name[0].toUpperCase() + name.substring(1);
    final local = email.split('@').first.split(RegExp(r'[._+-]')).first;
    if (local.isEmpty) return null;
    return local[0].toUpperCase() + local.substring(1);
  }

  String get initials {
    final name = firstName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name.substring(0, name.length.clamp(1, 2)).toUpperCase();
    }
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
    Object? appLock = _unset,
    ReminderPreferences? reminders,
    Map<TransactionCategory, Money>? budgets,
    Map<String, SubscriptionDecision>? subscriptionDecisions,
    List<Debt>? debts,
    Money? debtPayment,
    PayoffStrategy? payoffStrategy,
    Object? firstName = _unset,
    Object? userId = _unset,
    bool? emailVerified,
    bool? marketingOptIn,
    Object? trialEndsAt = _unset,
    bool? trialUsed,
    Object? billingPeriod = _unset,
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
      appLock: identical(appLock, _unset) ? this.appLock : appLock as AppLock?,
      reminders: reminders ?? this.reminders,
      budgets: budgets ?? this.budgets,
      subscriptionDecisions:
          subscriptionDecisions ?? this.subscriptionDecisions,
      debts: debts ?? this.debts,
      debtPayment: debtPayment ?? this.debtPayment,
      payoffStrategy: payoffStrategy ?? this.payoffStrategy,
      firstName: identical(firstName, _unset)
          ? this.firstName
          : firstName as String?,
      userId: identical(userId, _unset) ? this.userId : userId as String?,
      emailVerified: emailVerified ?? this.emailVerified,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      trialEndsAt: identical(trialEndsAt, _unset)
          ? this.trialEndsAt
          : trialEndsAt as DateTime?,
      trialUsed: trialUsed ?? this.trialUsed,
      billingPeriod: identical(billingPeriod, _unset)
          ? this.billingPeriod
          : billingPeriod as BillingPeriod?,
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
    'appLock': appLock?.toJson(),
    'reminders': reminders.toJson(),
    'budgets': {
      for (final entry in budgets.entries) entry.key.name: entry.value.cents,
    },
    'subscriptionDecisions': {
      for (final entry in subscriptionDecisions.entries)
        entry.key: entry.value.name,
    },
    'debts': debts == null ? null : [for (final debt in debts!) debt.toJson()],
    'debtPayment': debtPayment?.cents,
    'payoffStrategy': payoffStrategy.name,
    'firstName': firstName,
    'userId': userId,
    'emailVerified': emailVerified,
    'marketingOptIn': marketingOptIn,
    'trialEndsAt': trialEndsAt?.toIso8601String(),
    'trialUsed': trialUsed,
    'billingPeriod': billingPeriod?.name,
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
      appLock: AppLock.fromJson(json['appLock']),
      reminders: ReminderPreferences.fromJson(json['reminders']),
      budgets: {
        if (json['budgets'] case final Map raw)
          for (final entry in raw.entries)
            for (final category in TransactionCategory.values)
              if (category.name == entry.key && entry.value is int)
                category: Money.cents(entry.value as int),
      },
      subscriptionDecisions: {
        if (json['subscriptionDecisions'] case final Map raw)
          for (final entry in raw.entries)
            for (final decision in SubscriptionDecision.values)
              if (decision.name == entry.value) '${entry.key}': decision,
      },
      debts: json['debts'] is List
          ? [
              for (final raw in json['debts']! as List) ?Debt.fromJson(raw),
            ]
          : null,
      debtPayment: json['debtPayment'] is int
          ? Money.cents(json['debtPayment']! as int)
          : null,
      payoffStrategy:
          PayoffStrategy.values
              .where((value) => value.name == json['payoffStrategy'])
              .firstOrNull ??
          PayoffStrategy.avalanche,
      firstName: json['firstName'] as String?,
      userId: json['userId'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      marketingOptIn: json['marketingOptIn'] as bool? ?? false,
      trialEndsAt: DateTime.tryParse('${json['trialEndsAt']}'),
      trialUsed: json['trialUsed'] as bool? ?? false,
      billingPeriod: BillingPeriod.values
          .where((value) => value.name == json['billingPeriod'])
          .firstOrNull,
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
