import 'dart:async';

import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
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

  /// `null` follows the device language.
  void setLanguage(String? languageCode) =>
      _update(state.copyWith(languageCode: languageCode));

  /// Forgets everything and returns to the first onboarding screen.
  void reset() {
    // Keep the chosen language: restarting onboarding is not a reason to
    // switch the interface back to another language.
    _update(UserSession(languageCode: state.languageCode));
  }
}
