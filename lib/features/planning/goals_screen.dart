import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Plan targets and personal savings goals, both editable.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final targets = ref.watch(wealthTargetsProvider);
    final progress = ref.watch(goalProgressProvider);
    final session = ref.read(sessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.goalsTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            Text(
              l10n.goalsHeadline,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.goalsSubtitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SectionTitle(l10n.planTargetsSection),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SliderRow(
                      label: l10n.planSafetyBuffer,
                      value: l10n.bufferMonthsValue(targets.safetyBufferMonths),
                      slider: Slider(
                        value: targets.safetyBufferMonths
                            .clamp(3, 12)
                            .toDouble(),
                        min: 3,
                        max: 12,
                        divisions: 9,
                        label: '${targets.safetyBufferMonths}',
                        onChanged: (value) => session.setTargets(
                          targets.copyWith(safetyBufferMonths: value.round()),
                        ),
                      ),
                    ),
                    _SliderRow(
                      label: l10n.planLongTerm,
                      value: l10n.longTermShareValue(
                        (targets.longTermShare * 100).round(),
                      ),
                      slider: Slider(
                        value: targets.longTermShare.clamp(0.0, .8).toDouble(),
                        max: .8,
                        divisions: 16,
                        label: '${(targets.longTermShare * 100).round()}%',
                        onChanged: (value) => session.setTargets(
                          targets.copyWith(longTermShare: value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SectionTitle(l10n.savingsGoalsSection),
            progress.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(l10n.overviewUnavailable),
              data: (items) => items.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          l10n.noGoalsYet,
                          style: const TextStyle(color: finoraMutedInk),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _GoalCard(
                              progress: item,
                              onTap: () => showGoalEditor(context, item.goal),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => showGoalEditor(context, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.addGoal),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.slider,
  });
  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(value, style: const TextStyle(color: finoraMutedInk)),
          ],
        ),
        slider,
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.progress, required this.onTap});
  final GoalProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final goal = progress.goal;
    final deadline = goal.deadline;
    final monthly = progress.monthlyNeeded;
    final String status;
    if (progress.isReached) {
      status = l10n.goalReached;
    } else if (deadline == null || monthly == null) {
      status = l10n.goalNoDeadline;
    } else {
      status = l10n.goalByDate(
        DateFormat.yMMM(l10n.localeName).format(deadline),
        formatMoney(monthly),
      );
    }
    final percent = (progress.progress * 100).round();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: l10n.goalSemantics(
            goal.name,
            formatMoney(progress.saved),
            formatMoney(goal.target),
            percent,
          ),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      ValuePill(
                        label: '$percent%',
                        color: progress.isReached ? finoraGreen : finoraBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress.progress,
                      minHeight: 8,
                      backgroundColor: finoraBlue.withValues(alpha: .12),
                      valueColor: AlwaysStoppedAnimation(
                        progress.isReached ? finoraGreen : finoraBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.planProgressOf(
                      formatMoney(progress.saved),
                      formatMoney(goal.target),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: const TextStyle(color: finoraMutedInk, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the editor for [goal], or for a new goal when it is `null`.
Future<void> showGoalEditor(BuildContext context, SavingsGoal? goal) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GoalEditor(goal: goal),
  );
}

class _GoalEditor extends ConsumerStatefulWidget {
  const _GoalEditor({required this.goal});
  final SavingsGoal? goal;

  @override
  ConsumerState<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<_GoalEditor> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  DateTime? _deadline;
  late Set<String> _accountIds;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _name = TextEditingController(text: goal?.name ?? '');
    _target = TextEditingController(
      text: goal == null ? '' : goal.target.amount.round().toString(),
    );
    _deadline = goal?.deadline;
    _accountIds = {...?goal?.accountIds};
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  int? get _targetFrancs => int.tryParse(_target.text.replaceAll("'", ''));
  bool get _nameValid => _name.text.trim().isNotEmpty;
  bool get _targetValid => (_targetFrancs ?? 0) > 0;

  Future<void> _pickDeadline() async {
    final now = ref.read(clockProvider)();
    final current = _deadline;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(now)
          ? current
          : DateTime(now.year + 1, now.month),
      firstDate: now,
      lastDate: DateTime(now.year + 40),
    );
    if (!mounted || picked == null) return;
    setState(() => _deadline = picked);
  }

  void _save() {
    setState(() => _submitted = true);
    if (!_nameValid || !_targetValid) return;
    final existing = widget.goal;
    final goal = SavingsGoal(
      id:
          existing?.id ??
          'goal-${ref.read(clockProvider)().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      target: Money.cents(_targetFrancs! * 100),
      deadline: _deadline,
      accountIds: _accountIds,
    );
    ref.read(sessionProvider.notifier).saveGoal(goal);
    Navigator.pop(context);
  }

  void _delete() {
    final goal = widget.goal;
    if (goal == null) return;
    ref.read(sessionProvider.notifier).deleteGoal(goal.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accounts =
        ref.watch(accountsProvider).value ?? const <FinancialAccount>[];
    final institutions =
        ref.watch(institutionsProvider).value ?? const <Institution>[];
    String institutionName(String id) =>
        institutions.where((item) => item.id == id).firstOrNull?.name ?? id;
    final savingAccounts = accounts
        .where((account) => !account.type.isLiability)
        .toList();
    final deadline = _deadline;

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
                widget.goal == null ? l10n.addGoal : l10n.editGoal,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.goalNameLabel,
                  hintText: l10n.goalNameHint,
                  errorText: _submitted && !_nameValid
                      ? l10n.goalNameRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _target,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.goalTargetLabel,
                  prefixText: 'CHF ',
                  errorText: _submitted && !_targetValid
                      ? l10n.goalTargetRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDeadline,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        deadline == null
                            ? l10n.goalAddDeadline
                            : DateFormat.yMMMd(l10n.localeName).format(deadline),
                      ),
                    ),
                  ),
                  if (deadline != null)
                    IconButton(
                      tooltip: l10n.goalRemoveDeadline,
                      onPressed: () => setState(() => _deadline = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.goalAccountsLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final account in savingAccounts)
                    FilterChip(
                      label: Text(
                        '${institutionName(account.institutionId)} · ${account.name}',
                      ),
                      selected: _accountIds.contains(account.id),
                      onSelected: (selected) => setState(
                        () => selected
                            ? _accountIds.add(account.id)
                            : _accountIds.remove(account.id),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _save, child: Text(l10n.saveGoal)),
              if (widget.goal != null)
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: finoraDanger),
                  child: Text(l10n.deleteGoal),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
