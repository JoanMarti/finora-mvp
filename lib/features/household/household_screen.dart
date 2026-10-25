import 'package:finora/app/theme.dart';
import 'package:finora/application/household.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/household.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Both partners' finances together (Finora Plus).
class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isPlus = ref.watch(isPlusProvider);
    final household = ref.watch(householdProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.householdTitle),
        actions: [
          if (isPlus && household != null)
            IconButton(
              tooltip: l10n.householdEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showHouseholdEditor(context, household),
            ),
        ],
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            if (!isPlus)
              PlusLockedCard(
                title: l10n.householdLockedTitle,
                body: l10n.householdLockedBody,
              )
            else if (household == null)
              _Intro(onStart: () => showHouseholdEditor(context, null))
            else ...[
              const _NetWorthCard(),
              SectionTitle(l10n.householdBillsSection),
              const _SharedBillsCard(),
              SectionTitle(l10n.householdRetirementSection),
              _CoupleRetirementCard(household: household),
              if (household.relationship == Relationship.married) ...[
                const SizedBox(height: 12),
                Card(
                  color: finoraSoftBlue,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.householdJointTaxNote,
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.householdEstimateNote(household.partnerName),
                style: const TextStyle(
                  color: finoraMutedInk,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: finoraDanger),
                onPressed: () =>
                    ref.read(sessionProvider.notifier).setHousehold(null),
                child: Text(l10n.householdRemove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.family_restroom, color: finoraBlueText, size: 32),
            const SizedBox(height: 10),
            Text(
              l10n.householdIntroTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.householdIntroBody,
              style: const TextStyle(color: finoraMutedInk, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.householdAddPartner),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(householdSummaryProvider).value;
    final household = ref.watch(householdProvider);
    if (summary == null || household == null) return const SizedBox.shrink();
    final total = summary.netWorth.cents;
    int flex(Money part) =>
        total <= 0 ? 1 : (part.cents * 1000 ~/ total).clamp(1, 1000);
    return Card(
      color: finoraInk,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.householdNetWorth,
              style: const TextStyle(color: finoraSilver),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(summary.netWorth),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: flex(summary.myNetWorth),
                      child: const ColoredBox(color: finoraBlue),
                    ),
                    Expanded(
                      flex: flex(summary.partnerNetWorth),
                      child: const ColoredBox(color: Color(0xFF8ED8B9)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _Legend(
              color: finoraBlue,
              label: l10n.you,
              value: formatMoney(summary.myNetWorth),
            ),
            _Legend(
              color: const Color(0xFF8ED8B9),
              label: household.partnerName,
              value: formatMoney(summary.partnerNetWorth),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(color: finoraSilver)),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SharedBillsCard extends ConsumerWidget {
  const _SharedBillsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(householdSummaryProvider).value;
    final household = ref.watch(householdProvider);
    if (summary == null || household == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.householdBillsTotal(formatMoney(summary.sharedBills)),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.householdBillsSource,
              style: const TextStyle(color: finoraMutedInk, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SegmentedButton<SplitRule>(
              segments: [
                ButtonSegment(
                  value: SplitRule.byIncome,
                  label: Text(l10n.splitByIncome),
                ),
                ButtonSegment(
                  value: SplitRule.equal,
                  label: Text(l10n.splitEqual),
                ),
              ],
              selected: {household.splitRule},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => ref
                  .read(sessionProvider.notifier)
                  .setHousehold(household.copyWith(splitRule: selection.first)),
            ),
            const SizedBox(height: 12),
            _SplitRow(
              label: l10n.you,
              percent: (summary.myShare * 100).round(),
              value: formatMoney(summary.myPart),
            ),
            _SplitRow(
              label: household.partnerName,
              percent: 100 - (summary.myShare * 100).round(),
              value: formatMoney(summary.partnerPart),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.label,
    required this.percent,
    required this.value,
  });
  final String label;
  final int percent;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text('$percent%', style: const TextStyle(color: finoraMutedInk)),
        const SizedBox(width: 12),
        Text(
          context.l10n.perMonth(value),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _CoupleRetirementCard extends ConsumerWidget {
  const _CoupleRetirementCard({required this.household});
  final Household household;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final couple = ref.watch(coupleRetirementProvider).value;
    if (household.partnerRetirement == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.beach_access_outlined),
          title: Text(l10n.householdAddPension),
          subtitle: Text(l10n.householdAddPensionBody),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showHouseholdEditor(context, household),
        ),
      );
    }
    if (couple == null) return const SizedBox.shrink();
    final rows = [
      (l10n.householdAhv, couple.ahv),
      (l10n.householdOccupational, couple.occupational),
      (l10n.householdPillar3a, couple.pillar3a),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.perMonth(formatMoney(couple.totalMonthly)),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.householdRetirementCoverage(
                (couple.coverage * 100).round(),
                formatMoney(couple.targetMonthly),
              ),
              style: TextStyle(
                color: couple.coverage >= 1 ? finoraGreen : finoraWarning,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      l10n.perMonth(formatMoney(value)),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            if (couple.isCapped) ...[
              const SizedBox(height: 8),
              Text(
                l10n.householdAhvCapped(formatMoney(couple.capReduction)),
                style: const TextStyle(
                  color: finoraMutedInk,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sets up or edits the partner's figures.
Future<void> showHouseholdEditor(BuildContext context, Household? household) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HouseholdEditor(household: household),
  );
}

class _HouseholdEditor extends ConsumerStatefulWidget {
  const _HouseholdEditor({this.household});
  final Household? household;

  @override
  ConsumerState<_HouseholdEditor> createState() => _HouseholdEditorState();
}

class _HouseholdEditorState extends ConsumerState<_HouseholdEditor> {
  late Relationship _relationship =
      widget.household?.relationship ?? Relationship.married;
  late final _name = TextEditingController(
    text: widget.household?.partnerName ?? '',
  );
  late final _income = _francs(widget.household?.partnerMonthlyIncome);
  late final _cash = _francs(widget.household?.partnerCash);
  late final _investments = _francs(widget.household?.partnerInvestments);
  late final _pillar3a = _francs(widget.household?.partnerPillar3a);
  late final _debts = _francs(widget.household?.partnerDebts);
  late final _birthYear = TextEditingController(
    text: widget.household?.partnerRetirement?.birthYear.toString() ?? '',
  );
  late final _salary = _francs(
    widget.household?.partnerRetirement?.annualSalary,
  );
  late final _pensionBalance = _francs(
    widget.household?.partnerRetirement?.pensionFundBalance,
  );
  late final _pensionCredits = _francs(
    widget.household?.partnerRetirement?.annualPensionFundCredits,
  );
  bool _submitted = false;

  static TextEditingController _francs(Money? money) => TextEditingController(
    text: money == null || money.isZero ? '' : '${money.amount.round()}',
  );

  List<TextEditingController> get _controllers => [
    _name,
    _income,
    _cash,
    _investments,
    _pillar3a,
    _debts,
    _birthYear,
    _salary,
    _pensionBalance,
    _pensionCredits,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  int _read(TextEditingController controller) =>
      int.tryParse(controller.text) ?? 0;
  Money _money(TextEditingController controller) =>
      Money.cents(_read(controller) * 100);

  bool get _nameValid => _name.text.trim().isNotEmpty;

  /// The pension part is optional, but if a birth year is given it must be
  /// plausible and come with a salary.
  bool get _pensionValid {
    if (_birthYear.text.isEmpty) return true;
    final year = _read(_birthYear);
    final now = ref.read(clockProvider)();
    return year >= now.year - 70 &&
        year <= now.year - 16 &&
        _read(_salary) > 0;
  }

  void _save() {
    setState(() => _submitted = true);
    if (!_nameValid || !_pensionValid) return;
    final pension = _birthYear.text.isEmpty
        ? null
        : RetirementProfile(
            birthYear: _read(_birthYear),
            annualSalary: _money(_salary),
            pensionFundBalance: _money(_pensionBalance),
            annualPensionFundCredits: _money(_pensionCredits),
            annualPillar3aContribution: Money.zero,
          );
    ref
        .read(sessionProvider.notifier)
        .setHousehold(
          Household(
            partnerName: _name.text.trim(),
            relationship: _relationship,
            partnerMonthlyIncome: _money(_income),
            partnerCash: _money(_cash),
            partnerInvestments: _money(_investments),
            partnerPillar3a: _money(_pillar3a),
            partnerDebts: _money(_debts),
            partnerRetirement: pension,
            splitRule: widget.household?.splitRule ?? SplitRule.byIncome,
          ),
        );
    Navigator.pop(context);
  }

  Widget _number(
    TextEditingController controller,
    String label, {
    bool currency = true,
    String? error,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        prefixText: currency ? 'CHF ' : null,
        errorText: error,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.householdEditorTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.partnerNameLabel,
                  errorText: _submitted && !_nameValid
                      ? l10n.partnerNameRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SegmentedButton<Relationship>(
                segments: [
                  ButtonSegment(
                    value: Relationship.married,
                    label: Text(l10n.relationshipMarried),
                  ),
                  ButtonSegment(
                    value: Relationship.cohabiting,
                    label: Text(l10n.relationshipCohabiting),
                  ),
                ],
                selected: {_relationship},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _relationship = selection.first),
              ),
              const SizedBox(height: 16),
              _number(_income, l10n.partnerIncomeLabel),
              _number(_cash, l10n.partnerCashLabel),
              _number(_investments, l10n.partnerInvestmentsLabel),
              _number(_pillar3a, l10n.partnerPillar3aLabel),
              _number(_debts, l10n.partnerDebtsLabel),
              Text(
                l10n.partnerPensionSection,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _number(
                _birthYear,
                l10n.birthYearLabel,
                currency: false,
                error: _submitted && !_pensionValid
                    ? l10n.partnerPensionInvalid
                    : null,
              ),
              _number(_salary, l10n.annualSalaryLabel),
              _number(_pensionBalance, l10n.pensionFundBalanceLabel),
              _number(_pensionCredits, l10n.pensionFundCreditsLabel),
              const SizedBox(height: 8),
              FilledButton(onPressed: _save, child: Text(l10n.saveFigures)),
            ],
          ),
        ),
      ),
    );
  }
}
