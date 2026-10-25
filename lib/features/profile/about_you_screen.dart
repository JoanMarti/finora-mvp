import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/profile.dart';
import 'package:finora/features/simulators/simulator_widgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Everything about the user that shapes estimates and ideas. Saved as
/// each answer changes.
class AboutYouScreen extends ConsumerWidget {
  const AboutYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(userProfileProvider);
    final targets = ref.watch(wealthTargetsProvider);
    void save(UserProfile next) =>
        ref.read(sessionProvider.notifier).setProfile(next);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.aboutYouTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            const ProfileCompletenessCard(showAction: false),
            SectionTitle(l10n.profileSectionYou),
            ProfileBasicsForm(profile: profile, onChanged: save),
            const SizedBox(height: 16),
            _ChoiceWrap<CivilStatus>(
              values: CivilStatus.values,
              selected: profile.civilStatus,
              label: l10n.civilStatus,
              onSelected: (value) => save(profile.copyWith(civilStatus: value)),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.childrenLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _Stepper(
              value: profile.children,
              onChanged: (value) => save(profile.copyWith(children: value)),
            ),
            SectionTitle(l10n.profileSectionWork),
            MoneyField(
              key: const ValueKey('grossIncome'),
              label: l10n.grossIncomeLabel,
              value: profile.grossIncome ?? Money.zero,
              onChanged: (value) => save(
                profile.copyWith(grossIncome: value.isZero ? null : value),
              ),
            ),
            if (profile.isSelfEmployed && profile.grossIncome != null)
              SimulatorNote(
                l10n.pillar3aSelfEmployedNote(
                  formatMoneyWhole(targets.pillar3aAnnualLimit),
                ),
              ),
            SectionTitle(l10n.profileSectionHome),
            _ChoiceWrap<Housing>(
              values: Housing.values,
              selected: profile.housing,
              label: l10n.housing,
              onSelected: (value) => save(profile.copyWith(housing: value)),
            ),
            if (profile.isRenting) ...[
              const SizedBox(height: 12),
              MoneyField(
                key: const ValueKey('monthlyRent'),
                label: l10n.monthlyRentLabel,
                value: profile.monthlyRent ?? Money.zero,
                onChanged: (value) => save(
                  profile.copyWith(monthlyRent: value.isZero ? null : value),
                ),
              ),
              MoneyField(
                key: const ValueKey('rentDeposit'),
                label: l10n.rentDepositLabel,
                value: profile.rentDeposit ?? Money.zero,
                onChanged: (value) => save(
                  profile.copyWith(rentDeposit: value.isZero ? null : value),
                ),
              ),
            ],
            SectionTitle(l10n.profileSectionRisk),
            _RiskCard(profile: profile, onChanged: save),
            SectionTitle(l10n.profileSectionInterests),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in Interest.values)
                  FilterChip(
                    label: Text(l10n.interest(interest)),
                    selected: profile.interests.contains(interest),
                    onSelected: (selected) => save(
                      profile.copyWith(
                        interests: selected
                            ? {...profile.interests, interest}
                            : ({...profile.interests}..remove(interest)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Year of birth, canton, work and housing: the four answers asked during
/// onboarding and at the top of the profile.
class ProfileBasicsForm extends StatefulWidget {
  const ProfileBasicsForm({
    required this.profile,
    required this.onChanged,
    this.showWork = false,
    super.key,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  /// Onboarding asks about work and housing here; the full profile has
  /// their own sections.
  final bool showWork;

  @override
  State<ProfileBasicsForm> createState() => _ProfileBasicsFormState();
}

class _ProfileBasicsFormState extends State<ProfileBasicsForm> {
  late final TextEditingController _year = TextEditingController(
    text: widget.profile.birthYear?.toString() ?? '',
  );

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = widget.profile;
    final maxYear = DateTime.now().year - 16;
    final typed = int.tryParse(_year.text);
    final yearInvalid =
        _year.text.length == 4 &&
        (typed == null ||
            typed < UserProfile.earliestBirthYear ||
            typed > maxYear);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _year,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  labelText: l10n.birthYearLabel,
                  errorText: yearInvalid ? l10n.birthYearInvalid : null,
                ),
                onChanged: (value) {
                  setState(() {});
                  final year = int.tryParse(value);
                  final valid =
                      year != null &&
                      year >= UserProfile.earliestBirthYear &&
                      year <= maxYear;
                  if (valid) {
                    widget.onChanged(profile.copyWith(birthYear: year));
                  } else if (value.isEmpty) {
                    widget.onChanged(profile.copyWith(birthYear: null));
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<Canton>(
                initialValue: profile.canton,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.cantonLabel),
                items: [
                  for (final canton in Canton.values)
                    DropdownMenuItem(
                      value: canton,
                      child: Text(
                        '${canton.code} · ${canton.officialName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (canton) =>
                    widget.onChanged(profile.copyWith(canton: canton)),
              ),
            ),
          ],
        ),
        if (widget.showWork) ...[
          const SizedBox(height: 18),
          _ChoiceWrap<Employment>(
            values: Employment.values,
            selected: profile.employment,
            label: l10n.employment,
            onSelected: (value) =>
                widget.onChanged(profile.copyWith(employment: value)),
          ),
          const SizedBox(height: 14),
          _ChoiceWrap<Housing>(
            values: Housing.values,
            selected: profile.housing,
            label: l10n.housing,
            onSelected: (value) =>
                widget.onChanged(profile.copyWith(housing: value)),
          ),
        ] else ...[
          const SizedBox(height: 14),
          _ChoiceWrap<Employment>(
            values: Employment.values,
            selected: profile.employment,
            label: l10n.employment,
            onSelected: (value) =>
                widget.onChanged(profile.copyWith(employment: value)),
          ),
        ],
      ],
    );
  }
}

/// Single choice as chips; tapping the selected chip clears it.
class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in values)
        ChoiceChip(
          label: Text(label(value)),
          selected: value == selected,
          onSelected: (on) => onSelected(on ? value : null),
        ),
    ],
  );
}

/// Number of children: minus, the count, plus.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = value ?? 0;
    return Row(
      children: [
        IconButton.outlined(
          tooltip: '−',
          onPressed: count == 0 ? null : () => onChanged(count - 1),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 48,
          child: Text(
            value == null ? '–' : '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.outlined(
          tooltip: '+',
          onPressed: count >= 12 ? null : () => onChanged(value == null ? 0 : count + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.profile, required this.onChanged});
  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final risk = profile.risk;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const TonalIcon(Icons.show_chart, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        risk == null ? l10n.riskNotSet : l10n.riskProfile(risk),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (risk != null)
                        Text(
                          l10n.riskProfileBody(risk),
                          style: const TextStyle(color: finoraMutedInk),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final result = await showRiskCheck(context);
                  if (result != null) onChanged(profile.copyWith(risk: result));
                },
                child: Text(risk == null ? l10n.riskTakeCheck : l10n.riskRetake),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three-question risk check; returns the resulting profile.
Future<RiskProfile?> showRiskCheck(BuildContext context) =>
    showModalBottomSheet<RiskProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RiskCheck(),
    );

class _RiskCheck extends StatefulWidget {
  const _RiskCheck();

  @override
  State<_RiskCheck> createState() => _RiskCheckState();
}

class _RiskCheckState extends State<_RiskCheck> {
  final _answers = List<int?>.filled(RiskQuestionnaire.questions, null);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final questions = [
      (l10n.riskQ1, [l10n.riskQ1a, l10n.riskQ1b, l10n.riskQ1c]),
      (l10n.riskQ2, [l10n.riskQ2a, l10n.riskQ2b, l10n.riskQ2c]),
      (l10n.riskQ3, [l10n.riskQ3a, l10n.riskQ3b, l10n.riskQ3c]),
    ];
    final complete = _answers.every((answer) => answer != null);
    final result = complete
        ? RiskQuestionnaire.score([for (final answer in _answers) answer!])
        : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < questions.length; index++) ...[
              Text(
                questions[index].$1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              RadioGroup<int>(
                groupValue: _answers[index],
                onChanged: (value) => setState(() => _answers[index] = value),
                child: Column(
                  children: [
                    for (var option = 0; option < 3; option++)
                      RadioListTile<int>(
                        value: option,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(questions[index].$2[option]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (result != null)
              Text(
                l10n.riskResult(l10n.riskProfile(result)),
                style: const TextStyle(
                  color: finoraBlueText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: result == null
                  ? null
                  : () => Navigator.pop(context, result),
              child: Text(l10n.commonDone),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.riskDisclaimer,
              textAlign: TextAlign.center,
              style: const TextStyle(color: finoraMutedInk, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress bar of the profile, with a way to complete it.
class ProfileCompletenessCard extends ConsumerWidget {
  const ProfileCompletenessCard({this.showAction = true, super.key});
  final bool showAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final completeness = ref.watch(userProfileProvider).completeness;
    final percent = (completeness * 100).round();
    final card = Card(
      color: finoraSoftBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_pin_outlined, color: finoraBlueText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    showAction
                        ? l10n.profileNudgeTitle
                        : l10n.profileCompleteness(percent),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (showAction) ...[
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: finoraBlueText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: finoraBlueText),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(finoraRadiusSmall),
              child: LinearProgressIndicator(
                value: completeness,
                minHeight: 6,
                backgroundColor: finoraWhite,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              showAction ? l10n.profileNudgeBody : l10n.profilePrivacyNote,
              style: const TextStyle(
                color: finoraMutedInk,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
    if (!showAction) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(finoraRadius),
      onTap: () => context.push('/about-you'),
      child: card,
    );
  }
}
