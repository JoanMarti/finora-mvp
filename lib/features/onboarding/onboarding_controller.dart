import 'package:finora/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  const OnboardingState({
    this.email = '',
    this.products = const {},
    this.institutionIds = const {},
  });

  final String email;
  final Set<FinancialProductType> products;
  final Set<String> institutionIds;

  OnboardingState copyWith({
    String? email,
    Set<FinancialProductType>? products,
    Set<String>? institutionIds,
  }) {
    return OnboardingState(
      email: email ?? this.email,
      products: products ?? this.products,
      institutionIds: institutionIds ?? this.institutionIds,
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
}
