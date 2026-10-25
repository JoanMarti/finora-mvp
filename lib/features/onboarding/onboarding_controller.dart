import 'package:finora/domain/auth.dart';
import 'package:finora/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Draft answers while the user moves through onboarding. They become part
/// of the persisted session once the connection step completes. The
/// password only lives here until the account is created.
class OnboardingState {
  const OnboardingState({
    this.email = '',
    this.firstName = '',
    this.password = '',
    this.acceptedTerms = false,
    this.marketingOptIn = false,
    this.products = const {},
    this.institutionIds = const {},
    this.stepIndex = 0,
    this.skipAccountSteps = false,
  });

  final String email;
  final String firstName;
  final String password;
  final bool acceptedTerms;
  final bool marketingOptIn;
  final Set<FinancialProductType> products;
  final Set<String> institutionIds;

  /// Kept here (not in widget state) so returning from the connection step
  /// lands on the review instead of the welcome screen.
  final int stepIndex;

  /// Set after signing in: the account already exists, so onboarding starts
  /// with the products.
  final bool skipAccountSteps;

  bool get hasValidEmail => isValidEmail(email);
  bool get hasFirstName => firstName.trim().isNotEmpty;
  bool get hasValidPassword => PasswordPolicy.accepts(password, email: email);

  bool get canRegister =>
      hasFirstName && hasValidEmail && hasValidPassword && acceptedTerms;

  Registration get registration => Registration(
    firstName: firstName.trim(),
    email: email,
    password: password,
    acceptedTermsVersion: termsVersion,
    marketingOptIn: marketingOptIn,
  );

  OnboardingState copyWith({
    String? email,
    String? firstName,
    String? password,
    bool? acceptedTerms,
    bool? marketingOptIn,
    Set<FinancialProductType>? products,
    Set<String>? institutionIds,
    int? stepIndex,
    bool? skipAccountSteps,
  }) {
    return OnboardingState(
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      password: password ?? this.password,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      products: products ?? this.products,
      institutionIds: institutionIds ?? this.institutionIds,
      stepIndex: stepIndex ?? this.stepIndex,
      skipAccountSteps: skipAccountSteps ?? this.skipAccountSteps,
    );
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setEmail(String value) => state = state.copyWith(email: value.trim());

  void setFirstName(String value) => state = state.copyWith(firstName: value);

  void setPassword(String value) => state = state.copyWith(password: value);

  void setAcceptedTerms(bool value) =>
      state = state.copyWith(acceptedTerms: value);

  void setMarketingOptIn(bool value) =>
      state = state.copyWith(marketingOptIn: value);

  void setStep(int index) => state = state.copyWith(stepIndex: index);

  /// Forgets the password once the account exists.
  void clearPassword() => state = state.copyWith(password: '');

  /// After signing in: continue with the setup, or confirm the e-mail
  /// first when it is not confirmed yet.
  void continueAfterSignIn(String email, {required bool verified}) =>
      state = OnboardingState(
        email: email,
        skipAccountSteps: verified,
        // Verified: start with the plan. Otherwise open the code step
        // (after welcome and account).
        stepIndex: verified ? 0 : 2,
      );

  void toggleProduct(FinancialProductType product) {
    final next = {...state.products};
    next.contains(product) ? next.remove(product) : next.add(product);
    state = state.copyWith(products: next);
  }

  void toggleInstitution(String institutionId) {
    final next = {...state.institutionIds};
    next.contains(institutionId)
        ? next.remove(institutionId)
        : next.add(institutionId);
    state = state.copyWith(institutionIds: next);
  }

  void reset() => state = const OnboardingState();
}
