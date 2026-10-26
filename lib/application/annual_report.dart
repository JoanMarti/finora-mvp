import 'dart:typed_data';

import 'package:finora/application/offers.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/annual_report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// The last twelve completed months, or `null` before there are three.
final annualReportProvider = FutureProvider<AnnualReport?>((ref) async {
  final analysis = await ref.watch(spendingAnalysisProvider.future);
  final overview = await ref.watch(overviewProvider.future);
  final priceChanges = await ref.watch(priceChangesProvider.future);
  return AnnualReport.of(
    cashFlow: analysis.combined.cashFlowHistory,
    netWorth: overview.history,
    recurring: analysis.combined.recurringPayments,
    priceChanges: priceChanges,
    now: ref.watch(clockProvider)(),
  );
});

/// Hands a finished PDF to the system: the share sheet on Android, a
/// download on the web.
abstract interface class PdfSharer {
  Future<void> share(Uint8List bytes, String filename);
}

class PrintingPdfSharer implements PdfSharer {
  const PrintingPdfSharer();

  @override
  Future<void> share(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}

final pdfSharerProvider = Provider<PdfSharer>(
  (ref) => const PrintingPdfSharer(),
);
