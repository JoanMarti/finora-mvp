import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Projected retirement income across the three Swiss pillars.
class RetirementScreen extends ConsumerWidget {
  const RetirementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final projection = ref.watch(retirementProjectionProvider);
    final profile = ref.watch(retirementProfileProvider);
    final isExample = !ref.watch(hasOwnRetirementProfileProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.retirementTitle),
      ),
      body: FinoraPage(
        child: projection.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.overviewUnavailable)),
          data: (data) => ListView(
            children: [
              if (isExample) ...[
                _ExampleBanner(onEdit: () => _openEditor(context, profile)),
                const SizedBox(height: 12),
              ],
              _ProjectionSummary(projection: data, profile: profile),
              SectionTitle(l10n.threePillarsSection),
              _PillarBreakdown(projection: data),
              SectionTitle(l10n.scenariosSection),
              const _Scenarios(),
              SectionTitle(l10n.assumptionsSection),
              _Assumptions(profile: profile),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _openEditor(context, profile),
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.editMyFigures),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.retirementDisclaimer,
                style: const TextStyle(
                  color: finoraMutedInk,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, RetirementProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProfileEditor(profile: profile),
    );
  }
}

class _ExampleBanner extends StatelessWidget {
  const _ExampleBanner({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: finoraSoftBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: finoraBlueText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.exampleFiguresNote,
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onEdit,
                child: Text(l10n.useMyFigures),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectionSummary extends StatelessWidget {
  const _ProjectionSummary({required this.projection, required this.profile});
  final RetirementProjection projection;
  final RetirementProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onTrack = projection.onTrack;
    final statusColor = onTrack ? finoraGreen : finoraWarning;
    return HeroCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.estimatedIncomeFrom('${projection.retirementYear}'),
              style: const TextStyle(color: finoraSilver),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.perMonth(formatMoney(projection.totalMonthly)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.retirementTarget(
                formatMoney(projection.targetMonthly),
                (profile.replacementTarget * 100).round(),
              ),
              style: const TextStyle(color: finoraSilver, fontSize: 12),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(finoraRadiusSmall),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  onTrack
                      ? l10n.retirementOnTrack(
                          (projection.coverage * 100).round(),
                        )
                      : l10n.retirementGap(
                          formatMoney(projection.gapMonthly),
                        ),
                  style: TextStyle(
                    color: onTrack
                        ? const Color(0xFF8ED8B9)
                        : const Color(0xFFFFD27A),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillarBreakdown extends StatelessWidget {
  const _PillarBreakdown({required this.projection});
  final RetirementProjection projection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = projection.totalMonthly.cents;
    final pillars = [
      (
        l10n.pillarOneLabel,
        l10n.pillarOneDetail,
        projection.ahvMonthly,
        finoraBlue,
      ),
      (
        l10n.pillarTwoLabel,
        l10n.pillarCapital(formatMoney(projection.pensionFundCapital)),
        projection.pensionFundMonthly,
        finoraInk,
      ),
      (
        l10n.pillarThreeLabel,
        l10n.pillarCapital(formatMoney(projection.pillar3aCapital)),
        projection.pillar3aMonthly,
        finoraSlate,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    for (final (_, _, amount, color) in pillars)
                      if (amount.cents > 0)
                        Expanded(
                          flex: total <= 0
                              ? 1
                              : (amount.cents * 1000 ~/ total).clamp(1, 1000),
                          child: ColoredBox(color: color),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (final (label, detail, amount, color) in pillars)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            detail,
                            style: const TextStyle(
                              color: finoraMutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      l10n.perMonth(formatMoney(amount)),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Cautious / base / favourable projections side by side (Finora Plus).
class _Scenarios extends ConsumerWidget {
  const _Scenarios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (!ref.watch(isPlusProvider)) {
      return PlusLockedCard(
        title: l10n.scenariosLockedTitle,
        body: l10n.scenariosLockedBody,
      );
    }
    final scenarios = ref.watch(retirementScenariosProvider).value;
    if (scenarios == null) return const SizedBox.shrink();
    final rows = [
      for (final scenario in RetirementScenario.values)
        (
          scenario,
          switch (scenario) {
            RetirementScenario.cautious => l10n.scenarioCautious,
            RetirementScenario.base => l10n.scenarioBase,
            RetirementScenario.favourable => l10n.scenarioFavourable,
          },
          switch (scenario) {
            RetirementScenario.cautious => l10n.scenarioCautiousDetail,
            RetirementScenario.base => l10n.scenarioBaseDetail,
            RetirementScenario.favourable => l10n.scenarioFavourableDetail,
          },
          scenarios[scenario]!,
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rows[index].$2,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: rows[index].$1 == RetirementScenario.base
                                  ? finoraBlueText
                                  : finoraInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rows[index].$3,
                            style: const TextStyle(
                              color: finoraMutedInk,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.perMonth(formatMoney(rows[index].$4.totalMonthly)),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          l10n.scenarioCoverage(
                            (rows[index].$4.coverage * 100).round(),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: rows[index].$4.onTrack
                                ? finoraGreen
                                : finoraWarning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (index != rows.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _Assumptions extends StatelessWidget {
  const _Assumptions({required this.profile});
  final RetirementProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const rules = SwissPensionRules.y2026;
    final lines = [
      l10n.assumptionAhv,
      l10n.assumptionPensionFund(
        (rules.bvgMinimumInterest * 100).toStringAsFixed(2),
        (rules.bvgConversionRate * 100).toStringAsFixed(1),
      ),
      l10n.assumptionPillar3a(
        (profile.pillar3aReturn * 100).toStringAsFixed(1),
        rules.pillar3aDrawdownYears,
      ),
      l10n.assumptionTodaysFrancs,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: finoraSlate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditor extends ConsumerStatefulWidget {
  const _ProfileEditor({required this.profile});
  final RetirementProfile profile;

  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  late final TextEditingController _birthYear;
  late final TextEditingController _salary;
  late final TextEditingController _balance;
  late final TextEditingController _credits;
  late final TextEditingController _pillar3a;
  late double _return;
  late double _replacement;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    String francs(Money money) => money.amount.round().toString();
    _birthYear = TextEditingController(text: '${profile.birthYear}');
    _salary = TextEditingController(text: francs(profile.annualSalary));
    _balance = TextEditingController(text: francs(profile.pensionFundBalance));
    _credits = TextEditingController(
      text: francs(profile.annualPensionFundCredits),
    );
    _pillar3a = TextEditingController(
      text: francs(profile.annualPillar3aContribution),
    );
    _return = profile.pillar3aReturn;
    _replacement = profile.replacementTarget;
  }

  @override
  void dispose() {
    for (final controller in [
      _birthYear,
      _salary,
      _balance,
      _credits,
      _pillar3a,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _read(TextEditingController controller) =>
      int.tryParse(controller.text);

  bool get _birthYearValid {
    final year = _read(_birthYear);
    final now = ref.read(clockProvider)();
    return year != null && year >= now.year - 70 && year <= now.year - 16;
  }

  bool get _salaryValid => (_read(_salary) ?? 0) > 0;

  void _save() {
    setState(() => _submitted = true);
    if (!_birthYearValid || !_salaryValid) return;
    Money francs(TextEditingController controller) =>
        Money.cents((_read(controller) ?? 0) * 100);
    ref
        .read(sessionProvider.notifier)
        .setRetirementProfile(
          RetirementProfile(
            birthYear: _read(_birthYear)!,
            annualSalary: francs(_salary),
            pensionFundBalance: francs(_balance),
            annualPensionFundCredits: francs(_credits),
            annualPillar3aContribution: francs(_pillar3a),
            pillar3aReturn: _return,
            replacementTarget: _replacement,
          ),
        );
    Navigator.pop(context);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? prefix = 'CHF ',
    String? helper,
    String? error,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          helperText: helper,
          errorText: error,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.editMyFigures,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.certificateHint,
                style: const TextStyle(color: finoraMutedInk),
              ),
              const SizedBox(height: 16),
              _field(
                _birthYear,
                l10n.birthYearLabel,
                prefix: null,
                error: _submitted && !_birthYearValid
                    ? l10n.birthYearInvalid
                    : null,
              ),
              _field(
                _salary,
                l10n.annualSalaryLabel,
                error: _submitted && !_salaryValid
                    ? l10n.annualSalaryRequired
                    : null,
              ),
              _field(_balance, l10n.pensionFundBalanceLabel),
              _field(
                _credits,
                l10n.pensionFundCreditsLabel,
                helper: l10n.pensionFundCreditsHelp,
              ),
              _field(
                _pillar3a,
                l10n.pillar3aContributionLabel,
                helper: l10n.pillar3aContributionHelp,
              ),
              Text(
                l10n.pillar3aReturnLabel((_return * 100).toStringAsFixed(1)),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                value: _return.clamp(0.0, .05).toDouble(),
                max: .05,
                divisions: 10,
                label: '${(_return * 100).toStringAsFixed(1)}%',
                onChanged: (value) => setState(() => _return = value),
              ),
              Text(
                l10n.replacementLabel((_replacement * 100).round()),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                value: _replacement.clamp(.5, 1.0).toDouble(),
                min: .5,
                divisions: 10,
                label: '${(_replacement * 100).round()}%',
                onChanged: (value) => setState(() => _replacement = value),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _save, child: Text(l10n.saveFigures)),
            ],
          ),
        ),
      ),
    );
  }
}
