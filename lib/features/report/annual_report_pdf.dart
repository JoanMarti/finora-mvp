import 'package:finora/domain/annual_report.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/formatters.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _ink = PdfColor.fromInt(0xFF014164);
const _blue = PdfColor.fromInt(0xFF027DB9);
const _muted = PdfColor.fromInt(0xFF55666F);
const _fill = PdfColor.fromInt(0xFFEFEDEC);
const _green = PdfColor.fromInt(0xFF1E8E5A);
const _warning = PdfColor.fromInt(0xFFC7731A);

/// File name of the annual report, e.g. `finora-annual-report-2026-09.pdf`.
String annualReportFileName(AnnualReport report) =>
    'finora-annual-report-${DateFormat('yyyy-MM').format(report.end)}.pdf';

/// The annual report as an A4 PDF in the user's language.
Future<Uint8List> buildAnnualReportPdf(
  AnnualReport report,
  AppLocalizations l10n, {
  required DateTime createdAt,
  String? firstName,
}) async {
  Future<pw.Font> font(String weight) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-$weight.ttf'));
  final theme = pw.ThemeData.withFont(
    base: await font('Regular'),
    bold: await font('Bold'),
  );
  final month = DateFormat.yMMM(l10n.localeName);
  final range = l10n.annualReportRange(
    month.format(report.start),
    month.format(report.end),
  );
  final change = report.netWorthChange;
  final best = report.bestMonth;
  final toughest = report.toughestMonth;

  final document = pw.Document(
    title: '${l10n.annualReportHeading} · $range',
    author: 'Finora',
    creator: 'Finora',
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 32),
      theme: theme,
      footer: (context) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              l10n.annualReportPdfFooter(
                DateFormat.yMMMd(l10n.localeName).format(createdAt),
              ),
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    l10n.annualReportHeading,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    range,
                    style: const pw.TextStyle(fontSize: 12, color: _muted),
                  ),
                  if (firstName != null && firstName.isNotEmpty)
                    pw.Text(
                      l10n.annualReportPreparedFor(firstName),
                      style: const pw.TextStyle(fontSize: 10, color: _muted),
                    ),
                ],
              ),
            ),
            pw.Text(
              'Finora',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _blue,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: const pw.BoxDecoration(
            color: _ink,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                report.saved.isNegative
                    ? l10n.reportOverspent(formatMoney(report.saved.abs()))
                    : l10n.reportSaved(formatMoney(report.saved)),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                l10n.reportSavingsRate((report.savingsRate * 100).round()),
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromInt(0xFFD6E4EC),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            _figure(l10n.reportIncome, formatMoneyWhole(report.income)),
            pw.SizedBox(width: 8),
            _figure(l10n.reportSpending, formatMoneyWhole(report.spending)),
            pw.SizedBox(width: 8),
            _figure(
              l10n.reportNetWorth,
              change == null ? '–' : formatCompactMoney(change, signed: true),
            ),
            pw.SizedBox(width: 8),
            _figure(
              l10n.annualReportNetWorthEnd,
              report.netWorthEnd == null
                  ? '–'
                  : formatMoneyWhole(report.netWorthEnd!),
            ),
          ],
        ),
        _heading(l10n.annualReportMonthsSection),
        _savingsChart(report, l10n),
        pw.SizedBox(height: 10),
        pw.Text(
          l10n.annualReportBestMonth(
            DateFormat.yMMMM(l10n.localeName).format(best.month),
            formatMoney(AnnualReport.savedIn(best)),
          ),
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (!identical(best, toughest))
          pw.Text(
            l10n.annualReportToughestMonth(
              DateFormat.yMMMM(l10n.localeName).format(toughest.month),
              formatMoney(AnnualReport.savedIn(toughest), signed: true),
            ),
            style: const pw.TextStyle(fontSize: 10),
          ),
        pw.SizedBox(height: 12),
        _table(
          [
            l10n.annualReportMonthColumn,
            l10n.reportIncome,
            l10n.reportSpending,
            l10n.annualReportSavedColumn,
          ],
          [
            for (final point in report.months)
              [
                month.format(point.month),
                formatMoney(point.income),
                formatMoney(point.spending),
                formatMoney(AnnualReport.savedIn(point), signed: true),
              ],
          ],
        ),
        if (report.topBills.isNotEmpty) ...[
          _heading(l10n.annualReportBillsSection),
          _table(
            null,
            [
              for (final bill in report.topBills)
                [bill.merchant, formatMoney(bill.yearly)],
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            l10n.annualReportBillsTotal(formatMoneyWhole(report.recurringYearly)),
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (!report.priceIncreasesYearly.isZero)
            pw.Text(
              l10n.annualReportPriceIncreases(
                formatMoneyWhole(report.priceIncreasesYearly),
              ),
              style: const pw.TextStyle(fontSize: 10, color: _warning),
            ),
        ],
      ],
    ),
  );
  return document.save();
}

pw.Widget _heading(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 20, bottom: 8),
  child: pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  ),
);

pw.Widget _figure(String label, String value) => pw.Expanded(
  child: pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: const pw.BoxDecoration(
      color: _fill,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
      ],
    ),
  ),
);

/// One bar per month: green when money was saved, orange when not.
pw.Widget _savingsChart(AnnualReport report, AppLocalizations l10n) {
  const height = 90.0;
  final largest = report.months
      .map((point) => AnnualReport.savedIn(point).cents.abs())
      .fold<int>(1, (a, b) => a > b ? a : b);
  final label = DateFormat.MMM(l10n.localeName);
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      for (final point in report.months)
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  height: height *
                          AnnualReport.savedIn(point).cents.abs() /
                          largest +
                      1,
                  decoration: pw.BoxDecoration(
                    color: AnnualReport.savedIn(point).isNegative
                        ? _warning
                        : _green,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(2),
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  label.format(point.month),
                  style: const pw.TextStyle(fontSize: 7, color: _muted),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

pw.Widget _table(List<String>? header, List<List<String>> rows) {
  pw.Widget cell(String text, {bool bold = false, bool right = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? _ink : PdfColors.black,
          ),
        ),
      );
  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _fill, width: 0.8),
      bottom: pw.BorderSide(color: _fill, width: 0.8),
    ),
    children: [
      if (header != null)
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _fill),
          children: [
            for (var index = 0; index < header.length; index++)
              cell(header[index], bold: true, right: index > 0),
          ],
        ),
      for (final row in rows)
        pw.TableRow(
          children: [
            for (var index = 0; index < row.length; index++)
              cell(row[index], right: index > 0),
          ],
        ),
    ],
  );
}
