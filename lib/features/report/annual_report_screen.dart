import 'package:finora/app/theme.dart';
import 'package:finora/application/annual_report.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/annual_report.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/features/report/annual_report_pdf.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// "Your year in Finora": the last twelve months, with a PDF (Premium).
class AnnualReportScreen extends ConsumerStatefulWidget {
  const AnnualReportScreen({super.key});

  @override
  ConsumerState<AnnualReportScreen> createState() =>
      _AnnualReportScreenState();
}

class _AnnualReportScreenState extends ConsumerState<AnnualReportScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final premium = ref.watch(isPlusProvider);
    final report = ref.watch(annualReportProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.annualReportTitle),
      ),
      body: FinoraPage(
        child: switch (report) {
          AsyncData(value: null) => Center(
            child: Text(l10n.annualReportEmpty, textAlign: TextAlign.center),
          ),
          AsyncData(:final value?) => ListView(
            children: [
              if (!premium)
                PlusLockedCard(
                  title: l10n.annualReportLockedTitle,
                  body: l10n.annualReportLockedBody,
                )
              else ...[
                AnnualReportBody(report: value),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _download(value),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(l10n.annualReportDownload),
                ),
              ],
            ],
          ),
          AsyncError() => Center(
            child: Text(l10n.annualReportEmpty, textAlign: TextAlign.center),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Future<void> _download(AnnualReport report) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sharer = ref.read(pdfSharerProvider);
    final firstName = ref.read(sessionProvider).firstName;
    final now = ref.read(clockProvider)();
    setState(() => _busy = true);
    try {
      final bytes = await buildAnnualReportPdf(
        report,
        l10n,
        createdAt: now,
        firstName: firstName,
      );
      await sharer.share(bytes, annualReportFileName(report));
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.annualReportPdfFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The report on screen: totals, a bar per month and the biggest bills.
class AnnualReportBody extends StatelessWidget {
  const AnnualReportBody({required this.report, super.key});
  final AnnualReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final month = DateFormat.yMMM(l10n.localeName);
    final change = report.netWorthChange;
    final best = report.bestMonth;
    final toughest = report.toughestMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.annualReportHeading} · '
                  '${l10n.annualReportRange(month.format(report.start), month.format(report.end))}',
                  style: const TextStyle(color: finoraSilver),
                ),
                const SizedBox(height: 6),
                Text(
                  report.saved.isNegative
                      ? l10n.reportOverspent(formatMoney(report.saved.abs()))
                      : l10n.reportSaved(formatMoney(report.saved)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.reportSavingsRate((report.savingsRate * 100).round()),
                  style: const TextStyle(color: finoraSilver, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        KeyFigureGrid(
          figures: [
            (l10n.reportIncome, formatMoneyWhole(report.income)),
            (l10n.reportSpending, formatMoneyWhole(report.spending)),
            (
              l10n.reportNetWorth,
              change == null ? '–' : formatCompactMoney(change, signed: true),
            ),
            (
              l10n.annualReportNetWorthEnd,
              report.netWorthEnd == null
                  ? '–'
                  : formatMoneyWhole(report.netWorthEnd!),
            ),
          ],
        ),
        SectionTitle(l10n.annualReportMonthsSection),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SavingsBars(report: report),
                const SizedBox(height: 12),
                Text(
                  l10n.annualReportBestMonth(
                    formatMonthYear(best.month),
                    formatMoney(AnnualReport.savedIn(best)),
                  ),
                ),
                if (!identical(best, toughest))
                  Text(
                    l10n.annualReportToughestMonth(
                      formatMonthYear(toughest.month),
                      formatMoney(AnnualReport.savedIn(toughest), signed: true),
                    ),
                    style: const TextStyle(color: finoraMutedInk),
                  ),
              ],
            ),
          ),
        ),
        if (report.topBills.isNotEmpty) ...[
          SectionTitle(l10n.annualReportBillsSection),
          Card(
            child: Column(
              children: [
                for (final bill in report.topBills)
                  ListTile(
                    dense: true,
                    title: Text(bill.merchant),
                    trailing: Text(
                      formatMoney(bill.yearly),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFeatures: finoraTabular,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.annualReportBillsTotal(
                          formatMoneyWhole(report.recurringYearly),
                        ),
                        style: const TextStyle(color: finoraMutedInk),
                      ),
                      if (!report.priceIncreasesYearly.isZero)
                        Text(
                          l10n.annualReportPriceIncreases(
                            formatMoneyWhole(report.priceIncreasesYearly),
                          ),
                          style: const TextStyle(color: finoraWarning),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SavingsBars extends StatelessWidget {
  const _SavingsBars({required this.report});
  final AnnualReport report;

  @override
  Widget build(BuildContext context) {
    const height = 80.0;
    final largest = report.months
        .map((point) => AnnualReport.savedIn(point).cents.abs())
        .fold<int>(1, (a, b) => a > b ? a : b);
    final label = DateFormat('MMMMM', context.l10n.localeName);
    return SizedBox(
      height: height + 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in report.months)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height:
                          height *
                              AnnualReport.savedIn(point).cents.abs() /
                              largest +
                          2,
                      decoration: BoxDecoration(
                        color: AnnualReport.savedIn(point).isNegative
                            ? finoraWarning
                            : finoraGreen,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label.format(point.month),
                      style: const TextStyle(
                        fontSize: 11,
                        color: finoraMutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Link from the monthly report to the annual one.
class AnnualReportLinkCard extends ConsumerWidget {
  const AnnualReportLinkCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final premium = ref.watch(isPlusProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const TonalIcon(Icons.picture_as_pdf_outlined, size: 40),
        title: Text(
          l10n.annualReportTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(l10n.annualReportCardBody),
        trailing: premium
            ? const Icon(Icons.chevron_right)
            : ValuePill(label: l10n.plusBadge, color: finoraBlue),
        onTap: () => context.push('/annual-report'),
      ),
    );
  }
}
