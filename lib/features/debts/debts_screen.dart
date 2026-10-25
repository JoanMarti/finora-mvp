import 'package:finora/app/theme.dart';
import 'package:finora/application/debts.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/debts.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/features/simulators/simulator_widgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// A plan to become free of consumer debt: cards, loans and leasing.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final debts = ref.watch(debtsProvider).value;
    final payment = ref.watch(debtPaymentProvider).value;
    final strategy = ref.watch(
      sessionProvider.select((session) => session.payoffStrategy),
    );
    if (debts == null || payment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = ref.read(sessionProvider.notifier);
    void save(List<Debt> next) => session.setDebts(next);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.debtsTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDebtEditor(context, null, (debt) => save([...debts, debt])),
        icon: const Icon(Icons.add),
        label: Text(l10n.debtsAdd),
      ),
      body: FinoraPage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (debts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.debtsEmpty,
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              )
            else ...[
              _PlanCard(debts: debts, payment: payment, strategy: strategy),
              SectionTitle(l10n.debtsPaymentSection),
              MoneyField(
                key: ValueKey(debts.length),
                label: l10n.debtsPaymentLabel,
                helper: l10n.debtsPaymentHelp(
                  formatMoney(DebtPlanner.minimumTotal(debts)),
                ),
                value: payment,
                onChanged: (value) {
                  if (!value.isZero) session.setDebtPayment(value);
                },
              ),
              SegmentedButton<PayoffStrategy>(
                segments: [
                  ButtonSegment(
                    value: PayoffStrategy.avalanche,
                    label: Text(l10n.debtsAvalanche),
                  ),
                  ButtonSegment(
                    value: PayoffStrategy.snowball,
                    label: Text(l10n.debtsSnowball),
                  ),
                ],
                selected: {strategy},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    session.setPayoffStrategy(selection.first),
              ),
              SimulatorNote(
                strategy == PayoffStrategy.avalanche
                    ? l10n.debtsAvalancheHelp
                    : l10n.debtsSnowballHelp,
              ),
              SectionTitle(l10n.debtsListSection),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < debts.length; i++) ...[
                      ListTile(
                        title: Text(
                          debts[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            l10n.debtsRateMinimum(
                              (debts[i].yearlyRate * 100).toStringAsFixed(1),
                              formatMoney(debts[i].minimumPayment),
                            ),
                            if (debts[i].aboveLegalRate) l10n.debtsAboveLegal,
                          ].join(' · '),
                        ),
                        trailing: Text(
                          formatMoneyWhole(debts[i].balance),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => showDebtEditor(
                          context,
                          debts[i],
                          (debt) => save([
                            for (final item in debts)
                              item.id == debt.id ? debt : item,
                          ]),
                          onDelete: () => save([
                            for (final item in debts)
                              if (item.id != debts[i].id) item,
                          ]),
                        ),
                      ),
                      if (i != debts.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
            SimulatorNote(l10n.debtsLegalNote),
            SimulatorNote(l10n.debtsCardNote),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.debts,
    required this.payment,
    required this.strategy,
  });
  final List<Debt> debts;
  final Money payment;
  final PayoffStrategy strategy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(clockProvider)();
    final plan = DebtPlanner.simulate(debts, payment, strategy);
    final other = DebtPlanner.simulate(
      debts,
      payment,
      strategy == PayoffStrategy.avalanche
          ? PayoffStrategy.snowball
          : PayoffStrategy.avalanche,
    );
    String monthOf(int month) => DateFormat.yMMM(
      l10n.localeName,
    ).format(DateTime(now.year, now.month + month));
    final difference = other.totalInterest - plan.totalInterest;
    return Card(
      color: finoraInk,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.feasible ? l10n.debtsFreeBy : l10n.debtsNotFeasible,
              style: const TextStyle(color: finoraSilver),
            ),
            if (plan.feasible) ...[
              const SizedBox(height: 6),
              Text(
                monthOf(plan.months),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.debtsMonthsInterest(
                  plan.months,
                  formatMoney(plan.totalInterest),
                ),
                style: const TextStyle(color: finoraSilver, fontSize: 12),
              ),
              if (difference.cents > 0)
                Text(
                  l10n.debtsBetterThanOther(formatMoney(difference)),
                  style: const TextStyle(
                    color: Color(0xFF8ED8B9),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),
              for (final entry in plan.payoffMonths.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Color(0xFF8ED8B9), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          debts.firstWhere((debt) => debt.id == entry.key).name,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        monthOf(entry.value),
                        style: const TextStyle(color: finoraSilver),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Adds a debt or edits [debt]; [onSave] receives the result.
Future<void> showDebtEditor(
  BuildContext context,
  Debt? debt,
  ValueChanged<Debt> onSave, {
  VoidCallback? onDelete,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _DebtEditor(debt: debt, onSave: onSave, onDelete: onDelete),
);

class _DebtEditor extends StatefulWidget {
  const _DebtEditor({required this.debt, required this.onSave, this.onDelete});
  final Debt? debt;
  final ValueChanged<Debt> onSave;
  final VoidCallback? onDelete;

  @override
  State<_DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends State<_DebtEditor> {
  late DebtKind _kind = widget.debt?.kind ?? DebtKind.loan;
  late final _name = TextEditingController(text: widget.debt?.name ?? '');
  late final _balance = TextEditingController(
    text: widget.debt == null ? '' : '${widget.debt!.balance.amount.round()}',
  );
  late final _rate = TextEditingController(
    text: widget.debt == null
        ? ''
        : (widget.debt!.yearlyRate * 100).toStringAsFixed(1),
  );
  late final _minimum = TextEditingController(
    text: widget.debt == null
        ? ''
        : '${widget.debt!.minimumPayment.amount.round()}',
  );
  bool _submitted = false;

  @override
  void dispose() {
    for (final controller in [_name, _balance, _rate, _minimum]) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _francs => int.tryParse(_balance.text) ?? 0;
  int get _minimumFrancs => int.tryParse(_minimum.text) ?? 0;
  double? get _ratePercent =>
      double.tryParse(_rate.text.replaceAll(',', '.'));
  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _francs > 0 &&
      _minimumFrancs > 0 &&
      (_ratePercent ?? -1) >= 0 &&
      (_ratePercent ?? 100) < 100;

  void _save() {
    setState(() => _submitted = true);
    if (!_valid) return;
    widget.onSave(
      Debt(
        id: widget.debt?.id ?? 'debt-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        kind: _kind,
        balance: Money.cents(_francs * 100),
        yearlyRate: _ratePercent! / 100,
        minimumPayment: Money.cents(_minimumFrancs * 100),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String kindLabel(DebtKind kind) => switch (kind) {
      DebtKind.creditCard => l10n.debtKindCard,
      DebtKind.loan => l10n.debtKindLoan,
      DebtKind.leasing => l10n.debtKindLeasing,
      DebtKind.other => l10n.debtKindOther,
    };
    Widget number(
      TextEditingController controller,
      String label, {
      String? prefix = 'CHF ',
      String? suffix,
      bool decimal = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: decimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
            : [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          suffixText: suffix,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.debt == null ? l10n.debtsAdd : l10n.debtsEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final kind in DebtKind.values)
                    ChoiceChip(
                      label: Text(kindLabel(kind)),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.assetNameLabel),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              number(_balance, l10n.debtsBalanceLabel),
              number(
                _rate,
                l10n.debtsRateLabel,
                prefix: null,
                suffix: '%',
                decimal: true,
              ),
              number(_minimum, l10n.debtsMinimumLabel),
              if (_submitted && !_valid)
                Text(
                  l10n.debtsInvalid,
                  style: const TextStyle(color: finoraDanger),
                ),
              const SizedBox(height: 8),
              FilledButton(onPressed: _save, child: Text(l10n.saveAsset)),
              if (widget.onDelete != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: finoraDanger),
                  onPressed: () {
                    widget.onDelete!();
                    Navigator.pop(context);
                  },
                  child: Text(l10n.debtsDelete),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
