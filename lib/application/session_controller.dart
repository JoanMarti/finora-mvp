import 'dart:async';
import 'dart:math';

import 'package:finora/domain/app_lock.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/domain/auth.dart';
import 'package:finora/domain/budgets.dart';
import 'package:finora/domain/debts.dart';
import 'package:finora/domain/household.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/opportunities.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/domain/reminders.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/domain/user_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the session is persisted. Defaults to memory; `main.dart` replaces it
/// with on-device storage.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => InMemorySessionStore(),
);

final sessionProvider = NotifierProvider<SessionController, UserSession>(
  SessionController.new,
);

class SessionController extends Notifier<UserSession> {
  @override
  UserSession build() =>
      ref.watch(sessionStoreProvider).load() ?? const UserSession();

  void _update(UserSession next) {
    state = next;
    unawaited(ref.read(sessionStoreProvider).save(next));
  }

  /// Finishes onboarding with the institutions that were actually connected.
  void completeOnboarding({
    required String email,
    required Set<FinancialProductType> products,
    required Set<String> connectedInstitutionIds,
  }) {
    _update(
      state.copyWith(
        email: email,
        products: products,
        connectedInstitutionIds: connectedInstitutionIds,
        onboardingCompleted: true,
      ),
    );
  }

  /// Skips onboarding with a complete demo profile, keeping any e-mail the
  /// user already typed.
  void useDemoData({String email = ''}) {
    final demo = UserSession.demo();
    _update(demo.copyWith(email: email.isEmpty ? demo.email : email));
  }

  void connect(String institutionId) {
    final institution = InstitutionCatalogue.byId(institutionId);
    if (institution == null) return;
    _update(
      state.copyWith(
        connectedInstitutionIds: {
          ...state.connectedInstitutionIds,
          institutionId,
        },
        // Make sure the newly connected products are not filtered out.
        products: state.products.isEmpty
            ? state.products
            : {...state.products, ...institution.productTypes},
      ),
    );
  }

  void disconnect(String institutionId) {
    _update(
      state.copyWith(
        connectedInstitutionIds: {...state.connectedInstitutionIds}
          ..remove(institutionId),
      ),
    );
  }

  void setDataHealthAlerts(bool enabled) =>
      _update(state.copyWith(dataHealthAlerts: enabled));

  void setTargets(WealthTargets targets) =>
      _update(state.copyWith(targets: targets));

  /// Adds [goal], or replaces the goal with the same id.
  void saveGoal(SavingsGoal goal) {
    final exists = state.goals.any((item) => item.id == goal.id);
    _update(
      state.copyWith(
        goals: exists
            ? [
                for (final item in state.goals)
                  item.id == goal.id ? goal : item,
              ]
            : [...state.goals, goal],
      ),
    );
  }

  void deleteGoal(String id) => _update(
    state.copyWith(
      goals: [
        for (final item in state.goals)
          if (item.id != id) item,
      ],
    ),
  );

  /// Adds [asset], or replaces the asset with the same id.
  void saveAsset(ManualAsset asset) {
    final exists = state.manualAssets.any((item) => item.id == asset.id);
    _update(
      state.copyWith(
        manualAssets: exists
            ? [
                for (final item in state.manualAssets)
                  item.id == asset.id ? asset : item,
              ]
            : [...state.manualAssets, asset],
      ),
    );
  }

  void deleteAsset(String id) => _update(
    state.copyWith(
      manualAssets: [
        for (final item in state.manualAssets)
          if (item.id != id) item,
      ],
    ),
  );

  void setRetirementProfile(RetirementProfile profile) =>
      _update(state.copyWith(retirement: profile));

  DateTime get _now => ref.read(clockProvider)();

  List<ConsentRecord> _logged(ConsentRecord record) => [
    ...state.consentLog,
    record,
  ];

  /// Records the user's answer to the personalised-offers question, and
  /// keeps a timestamped copy of it in the consent register.
  void setOffersConsent(bool consent) {
    if (state.offersConsent == consent) return;
    _update(
      state.copyWith(
        offersConsent: consent,
        consentLog: _logged(
          ConsentRecord(
            purpose: ConsentPurpose.offersAnalysis,
            granted: consent,
            at: _now,
          ),
        ),
      ),
    );
  }

  /// Records that the user agreed to share one offer's data with its
  /// partner.
  void recordPartnerConsent(OpportunityKind kind) => _update(
    state.copyWith(
      consentLog: _logged(
        ConsentRecord(
          purpose: ConsentPurpose.partnerSharing,
          granted: true,
          at: _now,
          subject: kind.name,
        ),
      ),
    ),
  );

  /// Withdraws every offer-related consent and deletes the offer data kept
  /// on this device (hidden offers and the funnel counts). The register
  /// keeps the withdrawal itself.
  void withdrawOfferConsents() {
    final now = _now;
    // Partner consents whose latest answer is still "yes".
    final latest = <String, bool>{};
    for (final record in state.consentLog) {
      if (record.purpose == ConsentPurpose.partnerSharing &&
          record.subject != null) {
        latest[record.subject!] = record.granted;
      }
    }
    final sharedKinds = [
      for (final entry in latest.entries)
        if (entry.value) entry.key,
    ];
    _update(
      state.copyWith(
        offersConsent: false,
        dismissedOpportunities: const {},
        funnel: const FunnelStats(),
        consentLog: [
          ...state.consentLog,
          if (state.offersConsent == true)
            ConsentRecord(
              purpose: ConsentPurpose.offersAnalysis,
              granted: false,
              at: now,
            ),
          for (final kind in sharedKinds)
            ConsentRecord(
              purpose: ConsentPurpose.partnerSharing,
              granted: false,
              at: now,
              subject: kind,
            ),
        ],
      ),
    );
  }

  void recordOfferEvent(Opportunity opportunity, OfferEventType type) =>
      _update(state.copyWith(funnel: state.funnel.record(opportunity, type)));

  /// Demo purchase: a real build would confirm the payment with the App
  /// Store or Google Play before switching the plan.
  /// Unlocks Plus after a successful purchase or restore; [since] is the
  /// subscription start reported by the store.
  void startPlus({DateTime? since}) => _update(
    state.copyWith(plan: FinoraPlan.plus, plusSince: since ?? _now),
  );

  void cancelPlus() =>
      _update(state.copyWith(plan: FinoraPlan.free, plusSince: null));

  void dismissOpportunity(String id) => _update(
    state.copyWith(
      dismissedOpportunities: {...state.dismissedOpportunities, id},
    ),
  );

  void restoreOpportunities() =>
      _update(state.copyWith(dismissedOpportunities: const {}));

  /// The anonymous installation id, created on first use.
  String ensureInstallationId() {
    final existing = state.installationId;
    if (existing != null) return existing;
    final random = Random.secure();
    final id = [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    _update(state.copyWith(installationId: id));
    return id;
  }

  /// Sets the monthly limit for [category]; `null` removes the budget.
  void setBudget(TransactionCategory category, Money? limit) {
    final next = {...state.budgets};
    if (limit == null || limit.isZero) {
      next.remove(category);
    } else {
      next[category] = limit;
    }
    _update(state.copyWith(budgets: next));
  }

  void setBudgets(Map<TransactionCategory, Money> budgets) =>
      _update(state.copyWith(budgets: {...state.budgets, ...budgets}));

  /// Records the user's decision for a subscription; `null` clears it.
  void decideSubscription(String merchant, SubscriptionDecision? decision) {
    final next = {...state.subscriptionDecisions};
    if (decision == null) {
      next.remove(merchant);
    } else {
      next[merchant] = decision;
    }
    _update(state.copyWith(subscriptionDecisions: next));
  }

  void setDebts(List<Debt> debts) => _update(state.copyWith(debts: debts));

  void setDebtPayment(Money payment) =>
      _update(state.copyWith(debtPayment: payment));

  void setPayoffStrategy(PayoffStrategy strategy) =>
      _update(state.copyWith(payoffStrategy: strategy));

  void setReminders(ReminderPreferences reminders) =>
      _update(state.copyWith(reminders: reminders));

  void setAppLock(AppLock? lock) => _update(state.copyWith(appLock: lock));

  void setHousehold(Household? household) =>
      _update(state.copyWith(household: household));

  void setHideAmounts(bool hidden) =>
      _update(state.copyWith(hideAmounts: hidden));

  /// `null` follows the device language.
  void setLanguage(String? languageCode) =>
      _update(state.copyWith(languageCode: languageCode));

  /// Links the session to [account] after sign-up or sign-in. On sign-up,
  /// [acceptedTerms] records the terms and the optional marketing answer
  /// in the consent register.
  void signedIn(
    AuthAccount account, {
    bool acceptedTerms = false,
    bool marketingOptIn = false,
  }) {
    final now = _now;
    _update(
      state.copyWith(
        email: account.email,
        firstName: account.firstName.isEmpty ? null : account.firstName,
        userId: account.id,
        emailVerified: account.emailVerified,
        marketingOptIn: acceptedTerms ? marketingOptIn : null,
        consentLog: [
          ...state.consentLog,
          if (acceptedTerms) ...[
            ConsentRecord(
              purpose: ConsentPurpose.terms,
              granted: true,
              at: now,
              textVersion: termsVersion,
            ),
            ConsentRecord(
              purpose: ConsentPurpose.marketing,
              granted: marketingOptIn,
              at: now,
            ),
          ],
        ],
      ),
    );
  }

  /// Product news by e-mail; every change is kept in the register.
  void setMarketingOptIn(bool optIn) => _update(
    state.copyWith(
      marketingOptIn: optIn,
      consentLog: [
        ...state.consentLog,
        ConsentRecord(
          purpose: ConsentPurpose.marketing,
          granted: optIn,
          at: _now,
        ),
      ],
    ),
  );

  void markEmailVerified() => _update(state.copyWith(emailVerified: true));

  /// Ends the session on this device. Data shown in the app comes from the
  /// banks and is fetched again after the next sign-in.
  void signOut() => reset();

  /// Forgets everything and returns to the first onboarding screen.
  void reset() {
    // Keep the chosen language: restarting onboarding is not a reason to
    // switch the interface back to another language.
    _update(UserSession(languageCode: state.languageCode));
  }
}
