import 'package:finora/app/theme.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Step {
  welcome,
  account,
  products,
  banks,
  investments,
  retirement,
  review,
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  List<_Step> _stepsFor(Set<FinancialProductType> products) {
    return [
      _Step.welcome,
      _Step.account,
      _Step.products,
      _Step.banks,
      if (products.contains(FinancialProductType.investments))
        _Step.investments,
      if (products.contains(FinancialProductType.pillar3a)) _Step.retirement,
      _Step.review,
    ];
  }

  OnboardingController get _controller => ref.read(onboardingProvider.notifier);

  void next() {
    final state = ref.read(onboardingProvider);
    final last = _stepsFor(state.products).length - 1;
    _controller.setStep((state.stepIndex + 1).clamp(0, last));
  }

  void back() {
    final state = ref.read(onboardingProvider);
    final last = _stepsFor(state.products).length - 1;
    _controller.setStep((state.stepIndex - 1).clamp(0, last));
  }

  void _useDemoData() {
    ref
        .read(sessionProvider.notifier)
        .useDemoData(email: ref.read(onboardingProvider).email);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final activeSteps = _stepsFor(state.products);
    final index = state.stepIndex.clamp(0, activeSteps.length - 1);
    final step = activeSteps[index];

    return Scaffold(
      body: SafeArea(
        child: FinoraPage(
          child: Column(
            children: [
              if (step != _Step.welcome) ...[
                Row(
                  children: [
                    IconButton(
                      tooltip: context.l10n.commonBack,
                      onPressed: back,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          semanticsLabel: context.l10n.onboardingProgress,
                          value: index / (activeSteps.length - 1),
                          minHeight: 6,
                          backgroundColor: finoraBorder,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _content(step, state, key: ValueKey(step)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(_Step step, OnboardingState state, {required Key key}) {
    final l10n = context.l10n;
    return switch (step) {
      _Step.welcome => _Welcome(
        key: key,
        onContinue: next,
        onUseDemoData: _useDemoData,
      ),
      _Step.account => _AccountStep(
        key: key,
        email: state.email,
        onChanged: _controller.setEmail,
        onContinue: state.hasValidEmail ? next : null,
        showEmailError: state.email.isNotEmpty && !state.hasValidEmail,
      ),
      _Step.products => _SelectionStep<FinancialProductType>(
        key: key,
        title: l10n.productsTitle,
        subtitle: l10n.productsSubtitle,
        options: FinancialProductType.values,
        selected: state.products,
        label: l10n.productType,
        onToggle: _controller.toggleProduct,
        onContinue: state.products.isNotEmpty ? next : null,
      ),
      _Step.banks => _SelectionStep<String>(
        key: key,
        title: l10n.banksTitle,
        subtitle: l10n.banksSubtitle,
        options: _idsOffering({
          FinancialProductType.currentAccount,
          FinancialProductType.savings,
        }),
        selected: state.institutionIds,
        label: InstitutionCatalogue.nameOf,
        onToggle: _controller.toggleInstitution,
        onContinue: state.institutionIds.isNotEmpty ? next : null,
      ),
      _Step.investments => _SelectionStep<String>(
        key: key,
        title: l10n.investTitle,
        subtitle: l10n.investSubtitle,
        options: _idsOffering({FinancialProductType.investments}),
        selected: state.institutionIds,
        label: InstitutionCatalogue.nameOf,
        onToggle: _controller.toggleInstitution,
        onContinue: next,
        canSkip: true,
      ),
      _Step.retirement => _SelectionStep<String>(
        key: key,
        title: l10n.pillarTitle,
        subtitle: l10n.pillarSubtitle,
        options: _idsOffering({FinancialProductType.pillar3a}),
        selected: state.institutionIds,
        label: InstitutionCatalogue.nameOf,
        onToggle: _controller.toggleInstitution,
        onContinue: next,
        canSkip: true,
      ),
      _Step.review => _ReviewStep(key: key, state: state),
    };
  }
}

List<String> _idsOffering(Set<FinancialProductType> types) => [
  for (final institution in InstitutionCatalogue.offering(types)) institution.id,
];

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.onContinue,
    required this.onUseDemoData,
    super.key,
  });
  final VoidCallback onContinue;
  final VoidCallback onUseDemoData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: finoraBlue,
            borderRadius: BorderRadius.circular(finoraRadius),
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          l10n.welcomeTitle,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 18),
        Text(
          l10n.welcomeBody,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _TrustLine(icon: Icons.visibility_outlined, text: l10n.trustReadOnly),
        _TrustLine(icon: Icons.lock_outline, text: l10n.trustControl),
        const Spacer(),
        FilledButton(onPressed: onContinue, child: Text(l10n.getStarted)),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: onUseDemoData,
            child: Text(l10n.exploreDemoData),
          ),
        ),
        Center(
          child: Text(
            l10n.privateDemoNote,
            style: const TextStyle(color: finoraMutedInk),
          ),
        ),
      ],
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: finoraBlue),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.email,
    required this.onChanged,
    required this.onContinue,
    required this.showEmailError,
    super.key,
  });
  final String email;
  final ValueChanged<String> onChanged;
  final VoidCallback? onContinue;
  final bool showEmailError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.createAccountTitle,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.createAccountBody,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 30),
        TextFormField(
          initialValue: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: l10n.emailLabel,
            prefixIcon: const Icon(Icons.mail_outline),
            errorText: showEmailError ? l10n.emailInvalid : null,
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 14),
        TextField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.passwordLabel,
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: l10n.passwordDemoHint,
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onContinue,
          child: Text(l10n.createMockAccount),
        ),
      ],
    );
  }
}

class _SelectionStep<T> extends StatelessWidget {
  const _SelectionStep({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.label,
    required this.onToggle,
    required this.onContinue,
    this.canSkip = false,
    super.key,
  });
  final String title;
  final String subtitle;
  final List<T> options;
  final Set<T> selected;
  final String Function(T) label;
  final ValueChanged<T> onToggle;
  final VoidCallback? onContinue;
  final bool canSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = selected.contains(option);
              return Material(
                color: isSelected ? finoraSoftBlue : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(finoraRadius),
                  side: BorderSide(
                    color: isSelected ? finoraBlue : finoraBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () => onToggle(option),
                  borderRadius: BorderRadius.circular(finoraRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 17,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label(option),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected
                              ? finoraBlue
                              : finoraSlate,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: onContinue,
          child: Text(context.l10n.commonContinue),
        ),
        if (canSkip)
          Center(
            child: TextButton(
              onPressed: onContinue,
              child: Text(context.l10n.addLater),
            ),
          ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state, super.key});
  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final institutions = state.institutionIds.toList()..sort();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.reviewTitle,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.reviewSummary(
            l10n.productCount(state.products.length),
            l10n.institutionCount(institutions.length),
          ),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.products
                        .map((item) => Chip(label: Text(l10n.productType(item))))
                        .toList(),
                  ),
                ),
              ),
              SectionTitle(l10n.institutionsSection),
              ...institutions.map(
                (id) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: finoraSoftBlue,
                      child: Icon(
                        Icons.account_balance_outlined,
                        color: finoraBlue,
                      ),
                    ),
                    title: Text(
                      InstitutionCatalogue.nameOf(id),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      InstitutionCatalogue.byId(id)?.isManual ?? false
                          ? l10n.manualConnectionAvailable
                          : l10n.secureConnectionAvailable,
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: finoraGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: finoraSoftBlue,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: finoraBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.readOnlyPromise,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => context.go('/connect'),
          child: Text(l10n.continueToConnections),
        ),
      ],
    );
  }
}
