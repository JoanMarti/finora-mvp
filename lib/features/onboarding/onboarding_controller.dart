import 'package:finora/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Draft answers while the user moves through onboarding. They become part
/// of the persisted session once the connection step completes.
class OnboardingState {
  const OnboardingState({
    this.email = '',
    this.products = const {},
    this.institutionIds = const {},
    this.stepIndex = 0,
  });

  final String email;
  final Set<FinancialProductType> products;
  final Set<String> institutionIds;

  /// Kept here (not in widget state) so returning from the connection step
  /// lands on the review instead of the welcome screen.
  final int stepIndex;

  bool get hasValidEmail => _emailPattern.hasMatch(email);

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  OnboardingState copyWith({
    String? email,
    Set<FinancialProductType>? products,
    Set<String>? institutionIds,
    int? stepIndex,
  }) {
    return OnboardingState(
      email: email ?? this.email,
      products: products ?? this.products,
      institutionIds: institutionIds ?? this.institutionIds,
      stepIndex: stepIndex ?? this.stepIndex,
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

  void setStep(int index) => state = state.copyWith(stepIndex: index);

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
