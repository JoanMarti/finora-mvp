import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Year-end figures prepared the way a Swiss tax return asks for them.
class TaxSummaryScreen extends ConsumerStatefulWidget {
  const TaxSummaryScreen({super.key});

  @override
  ConsumerState<TaxSummaryScreen> createState() => _TaxSummaryScreenState();
}

class _TaxSummaryScreenState extends ConsumerState<TaxSummaryScreen> {
  /// Defaults to last year: that is the return people file each spring.
  late int _year = ref.read(clockProvider)().year - 1;

  Future<void> _copyCsv(TaxYearSummary summary, String Function(String) institutionName) async {
    final l10n = context.l10n;
    String amount(Money money) => money.amount.toStringAsFixed(2);
    final rows = [
      'section,institution,account,closing_balance,income,interest_paid,currency',
      for (final (section, items) in [
        ('bank', summary.bankAccounts),
        ('securities', summary.securities),
        ('debt', summary.debts),
        ('pillar3a', summary.pillar3aAccounts),
      ])
        for (final item in items)
          [
            section,
            _csv(institutionName(item.account.institutionId)),
            _csv(item.account.name),
            amount(item.closingBalance),
            amount(item.income),
            amount(item.interestPaid),
            item.closingBalance.currency,
          ].join(','),
      'pillar3a_contributions,,,${amount(summary.data.pillar3aContributions)},,,CHF',
      'pillar3a_deductible,,,${amount(summary.pillar3aDeductible)},,,CHF',
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.taxCsvCopied('${summary.data.year}'))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = ref.watch(clockProvider)();
    final summary = ref.watch(taxSummaryProvider(_year));
    final institutions =
        ref.watch(institutionsProvider).value ?? const <Institution>[];
    String institutionName(String id) =>
        institutions.where((item) => item.id == id).firstOrNull?.name ?? id;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.taxTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  for (final year in [now.year - 1, now.year])
                    ButtonSegment(value: year, label: Text('$year')),
                ],
                selected: {_year},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _year = selection.first),
              ),
            ),
            const SizedBox(height: 16),
            summary.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(l10n.overviewUnavailable),
              data: (data) => _TaxSummaryBody(
                summary: data,
                institutionName: institutionName,
                onCopy: () => _copyCsv(data, institutionName),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _csv(String value) => value.contains(RegExp('[",\n]'))
    ? '"${value.replaceAll('"', '""')}"'
    : value;

class _TaxSummaryBody extends StatelessWidget {
  const _TaxSummaryBody({
    required this.summary,
    required this.institutionName,
    required this.onCopy,
  });

  final TaxYearSummary summary;
  final String Function(String) institutionName;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = summary.data;
    final asOf = DateFormat.yMMMd(l10n.localeName).format(data.asOf);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          data.isComplete
              ? l10n.taxBalancesOn(asOf)
              : l10n.taxYearToDate(asOf),
          style: const TextStyle(color: finoraMutedInk),
        ),
        const SizedBox(height: 12),
        Card(
          color: finoraInk,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TotalRow(
                  label: l10n.taxNetWealth,
                  value: formatMoney(summary.netWealth),
                  emphasised: true,
                ),
                const SizedBox(height: 10),
                _TotalRow(
                  label: l10n.taxIncomeFromAssets,
                  value: formatMoney(summary.taxableIncome),
                ),
                _TotalRow(
                  label: l10n.taxPillar3aDeduction,
                  value: formatMoney(summary.pillar3aDeductible),
                ),
                _TotalRow(
                  label: l10n.taxDebtInterestDeduction,
                  value: formatMoney(summary.debtInterest),
                ),
              ],
            ),
          ),
        ),
        _TaxSection(
          title: l10n.taxBankAccounts,
          total: summary.bankTotal,
          items: summary.bankAccounts,
          institutionName: institutionName,
          incomeLabel: l10n.taxInterest,
        ),
        _TaxSection(
          title: l10n.taxSecurities,
          total: summary.securitiesTotal,
          items: summary.securities,
          institutionName: institutionName,
          incomeLabel: l10n.taxDividends,
        ),
        _TaxSection(
          title: l10n.taxDebts,
          total: -summary.debtTotal,
          items: summary.debts,
          institutionName: institutionName,
          incomeLabel: l10n.taxInterestPaid,
          showInterestPaid: true,
        ),
        SectionTitle(l10n.productPillar3a),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LineRow(
                  label: l10n.taxPillar3aContributions,
                  value: formatMoney(data.pillar3aContributions),
                ),
                _LineRow(
                  label: l10n.taxPillar3aDeductible,
                  value: formatMoney(summary.pillar3aDeductible),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.taxPillar3aNote,
                  style: const TextStyle(color: finoraMutedInk, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_all_outlined),
          label: Text(l10n.copyAsCsv),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.taxDisclaimer,
          style: const TextStyle(
            color: finoraMutedInk,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasised = false,
  });
  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasised ? Colors.white : finoraSilver,
                fontWeight: emphasised ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: emphasised ? 20 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _TaxSection extends StatelessWidget {
  const _TaxSection({
    required this.title,
    required this.total,
    required this.items,
    required this.institutionName,
    required this.incomeLabel,
    this.showInterestPaid = false,
  });

  final String title;
  final Money total;
  final List<TaxAccountFigures> items;
  final String Function(String) institutionName;
  final String incomeLabel;
  final bool showInterestPaid;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title,
          action: items.isEmpty
              ? null
              : Text(
                  formatMoney(total, signed: total.isNegative),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        Card(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.taxNothingToDeclare,
                    style: const TextStyle(color: finoraMutedInk),
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      ListTile(
                        title: Text(
                          items[index].account.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${institutionName(items[index].account.institutionId)} · '
                          '$incomeLabel ${formatMoney(showInterestPaid ? items[index].interestPaid : items[index].income)}',
                        ),
                        trailing: Text(
                          formatMoney(
                            items[index].closingBalance,
                            signed: items[index].closingBalance.isNegative,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (index != items.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
