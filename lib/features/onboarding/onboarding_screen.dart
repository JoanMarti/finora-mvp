import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/onboarding/onboarding_controller.dart';
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
  int index = 0;

  List<_Step> get steps {
    final products = ref.read(onboardingProvider).products;
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

  void next() => setState(() => index = (index + 1).clamp(0, steps.length - 1));
  void back() => setState(() => index = (index - 1).clamp(0, steps.length - 1));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final activeSteps = steps;
    if (index >= activeSteps.length) index = activeSteps.length - 1;
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
                      onPressed: back,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: index / (activeSteps.length - 1),
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE1E8E5),
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
    return switch (step) {
      _Step.welcome => _Welcome(key: key, onContinue: next),
      _Step.account => _AccountStep(
        key: key,
        email: state.email,
        onChanged: ref.read(onboardingProvider.notifier).setEmail,
        onContinue: state.email.contains('@') ? next : null,
      ),
      _Step.products => _SelectionStep<FinancialProductType>(
        key: key,
        title: 'What do you have?',
        subtitle: 'Select the products you want to see in your overview.',
        options: FinancialProductType.values,
        selected: state.products,
        label: (item) => item.label,
        onToggle: ref.read(onboardingProvider.notifier).toggleProduct,
        onContinue: state.products.isNotEmpty ? next : null,
      ),
      _Step.banks => _SelectionStep<String>(
        key: key,
        title: 'Where do you bank?',
        subtitle: 'Choose every banking relationship you use.',
        options: const ['ubs', 'zkb', 'postfinance', 'raiffeisen'],
        selected: state.institutionIds,
        label: _institutionName,
        onToggle: ref.read(onboardingProvider.notifier).toggleInstitution,
        onContinue: state.institutionIds.isNotEmpty ? next : null,
      ),
      _Step.investments => _SelectionStep<String>(
        key: key,
        title: 'Where do you invest?',
        subtitle: 'We kept banks you already selected. Add any other provider.',
        options: const ['ubs', 'swissquote', 'julius-baer', 'pictet'],
        selected: state.institutionIds,
        label: _institutionName,
        onToggle: ref.read(onboardingProvider.notifier).toggleInstitution,
        onContinue: next,
        canSkip: true,
      ),
      _Step.retirement => _SelectionStep<String>(
        key: key,
        title: 'Where is your Pillar 3a?',
        subtitle: 'Connected and manually entered providers can live together.',
        options: const ['frankly', 'viac', 'finpension', 'ubs'],
        selected: state.institutionIds,
        label: _institutionName,
        onToggle: ref.read(onboardingProvider.notifier).toggleInstitution,
        onContinue: next,
        canSkip: true,
      ),
      _Step.review => _ReviewStep(key: key, state: state),
    };
  }
}

String _institutionName(String id) =>
    const {
      'ubs': 'UBS',
      'zkb': 'Zürcher Kantonalbank',
      'postfinance': 'PostFinance',
      'raiffeisen': 'Raiffeisen',
      'swissquote': 'Swissquote',
      'julius-baer': 'Julius Baer',
      'pictet': 'Pictet',
      'frankly': 'frankly',
      'viac': 'VIAC',
      'finpension': 'finpension',
    }[id] ??
    id;

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onContinue, super.key});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: finoraGreen,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'Your finances.\nOne clear view.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 18),
        Text(
          'Bring your Swiss bank accounts, investments and Pillar 3a together—without giving us permission to move your money.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        const _TrustLine(
          icon: Icons.visibility_outlined,
          text: 'Read-only by design',
        ),
        const _TrustLine(icon: Icons.lock_outline, text: 'You stay in control'),
        const Spacer(),
        FilledButton(onPressed: onContinue, child: const Text('Get started')),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Private demo · no real bank data',
            style: TextStyle(color: Color(0xFF71807B)),
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
        Icon(icon, color: finoraGreen),
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
    super.key,
  });
  final String email;
  final ValueChanged<String> onChanged;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create your account',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          'This is a mock sign-up. Nothing leaves this device.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 30),
        TextFormField(
          initialValue: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 14),
        const TextField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
            helperText: 'Use any password for this demo',
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onContinue,
          child: const Text('Create mock account'),
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
                color: isSelected ? finoraMint : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: isSelected ? finoraGreen : const Color(0xFFE1E7E4),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () => onToggle(option),
                  borderRadius: BorderRadius.circular(18),
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
                              ? finoraGreen
                              : const Color(0xFF9AA7A2),
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
        FilledButton(onPressed: onContinue, child: const Text('Continue')),
        if (canSkip)
          Center(
            child: TextButton(
              onPressed: onContinue,
              child: const Text("I'll add this later"),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your financial setup',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          "We've found ${state.products.length} products across ${institutions.length} institutions.",
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
                        .map((item) => Chip(label: Text(item.label)))
                        .toList(),
                  ),
                ),
              ),
              const SectionTitle('Institutions'),
              ...institutions.map(
                (id) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: finoraMint,
                      child: Icon(
                        Icons.account_balance_outlined,
                        color: finoraGreen,
                      ),
                    ),
                    title: Text(
                      _institutionName(id),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      id == 'frankly' || id == 'viac' || id == 'finpension'
                          ? 'Manual connection available'
                          : 'Secure connection available',
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: finoraGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Card(
                color: finoraMint,
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: finoraGreen),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Finora can read balances and transactions. It can't pay, transfer or trade.",
                          style: TextStyle(fontWeight: FontWeight.w600),
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
          child: const Text('Continue to connections'),
        ),
      ],
    );
  }
}
