import 'package:finora/app/theme.dart';
import 'package:finora/application/calendar.dart';
import 'package:finora/application/health.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/report.dart';
import 'package:finora/domain/report.dart';
import 'package:finora/features/calendar/calendar_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

IconData _highlightIcon(ReportHighlightKind kind) => switch (kind) {
  ReportHighlightKind.bestSavingsMonth => Icons.emoji_events_outlined,
  ReportHighlightKind.spendingAboveAverage => Icons.trending_up,
  ReportHighlightKind.spendingBelowAverage => Icons.trending_down,
  ReportHighlightKind.netWorthUp => Icons.show_chart,
  ReportHighlightKind.netWorthDown => Icons.show_chart,
  ReportHighlightKind.subscriptionsSaved => Icons.subscriptions_outlined,
};

/// "Your month in Finora".
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final months = ref.watch(reportMonthsProvider).value;
    if (months == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final month = _month ?? months.firstOrNull;
    final report = month == null
        ? null
        : ref.watch(monthlyReportProvider(month)).value;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.reportScreenTitle),
        actions: [
          if (report != null)
            IconButton(
              tooltip: l10n.reportCopy,
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () => _copy(context, report),
            ),
        ],
      ),
      body: FinoraPage(
        child: month == null
            ? Center(child: Text(l10n.reportEmpty, textAlign: TextAlign.center))
            : ListView(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final option in months.take(5))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(formatMonthYear(option)),
                              selected: option == month,
                              onSelected: (_) => setState(() => _month = option),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (report == null)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _ReportBody(report: report),
                ],
              ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, MonthlyReport report) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: l10n.reportSummary(report)));
    messenger.showSnackBar(SnackBar(content: Text(l10n.reportCopied)));
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final change = report.spendingChange;
    final netWorth = report.netWorthChange;
    final previousRate = report.previousSavingsRate;
    final health = ref.watch(financialHealthProvider).value;
    final next = health?.nextStep;
    final now = ref.watch(clockProvider)();
    final upcoming = (ref.watch(calendarProvider).value ?? const [])
        .where((event) => event.daysFrom(now) <= 30)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: finoraInk,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reportTitle(formatMonthYear(report.month)),
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
                  [
                    l10n.reportSavingsRate((report.savingsRate * 100).round()),
                    if (previousRate != null)
                      l10n.reportPreviousRate((previousRate * 100).round()),
                  ].join(' · '),
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
            (
              l10n.reportSpending,
              change == null
                  ? formatMoneyWhole(report.spending)
                  : '${formatMoneyWhole(report.spending)} (${formatPercentChange(change)})',
            ),
            (
              l10n.reportNetWorth,
              netWorth == null
                  ? '–'
                  : formatCompactMoney(netWorth, signed: true),
            ),
            (l10n.reportAverageSpending, formatMoneyWhole(report.averageSpending)),
          ],
        ),
        if (report.highlights.isNotEmpty) ...[
          SectionTitle(l10n.reportHighlightsSection),
          Card(
            child: Column(
              children: [
                for (final highlight in report.highlights)
                  ListTile(
                    leading: Icon(
                      _highlightIcon(highlight.kind),
                      color: finoraBlueText,
                    ),
                    title: Text(l10n.reportHighlight(highlight)),
                  ),
              ],
            ),
          ),
        ],
        if (next != null || upcoming != null) ...[
          SectionTitle(l10n.reportNextSection),
          Card(
            child: Column(
              children: [
                if (next != null)
                  ListTile(
                    leading: const Icon(Icons.favorite_border),
                    title: Text(l10n.healthFactorTitle(next.kind)),
                    subtitle: Text(l10n.healthFactorAction(next)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(next.route),
                  ),
                if (upcoming != null)
                  CalendarEventTile(event: upcoming, now: now),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Dashboard entry to last month's report.
class MonthlyReportCard extends ConsumerWidget {
  const MonthlyReportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(reportMonthsProvider).value;
    final month = months?.firstOrNull;
    if (month == null) return const SizedBox.shrink();
    final report = ref.watch(monthlyReportProvider(month)).value;
    if (report == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: finoraMint,
          foregroundColor: finoraGreen,
          child: Icon(Icons.insights_outlined, size: 20),
        ),
        title: Text(
          l10n.reportCardTitle(formatMonthYear(month)),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          report.saved.isNegative
              ? l10n.reportOverspent(formatMoney(report.saved.abs()))
              : l10n.reportSaved(formatMoney(report.saved)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/report'),
      ),
    );
  }
}
