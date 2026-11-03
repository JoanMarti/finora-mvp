import 'package:finora/domain/models.dart';

/// Why a file could not be read as a bank statement.
enum StatementProblem { empty, noHeader, noDate, noAmount, noRows }

class StatementFormatException implements Exception {
  const StatementFormatException(this.problem);
  final StatementProblem problem;

  @override
  String toString() => 'StatementFormatException(${problem.name})';
}

/// One booking read from a statement.
class StatementRow {
  const StatementRow({
    required this.date,
    required this.text,
    required this.amount,
    this.balance,
  });

  final DateTime date;
  final String text;

  /// Negative for money going out.
  final Money amount;

  /// Account balance after this booking, when the file has one.
  final Money? balance;
}

/// The bookings of a CSV export, oldest first.
class ParsedStatement {
  const ParsedStatement({required this.rows, this.closingBalance});

  final List<StatementRow> rows;

  /// Balance after the newest booking, when the file has a balance column.
  final Money? closingBalance;

  DateTime get firstDate => rows.first.date;
  DateTime get lastDate => rows.last.date;

  Money get income => Money.sum([
    for (final row in rows)
      if (!row.amount.isNegative) row.amount,
  ]);

  Money get spending => Money.sum([
    for (final row in rows)
      if (row.amount.isNegative) row.amount.abs(),
  ]);
}

/// Reads the CSV exports of Swiss e-banking (UBS, PostFinance, cantonal
/// banks, Raiffeisen, neobanks…). Column names are recognised in German,
/// French, Italian and English; separators, number and date formats are
/// detected.
abstract final class StatementParser {
  static const _dateHeaders = [
    'buchungsdatum', 'abschlussdatum', 'transaktionsdatum', 'booking date',
    'date de comptabilisation', 'data contabile', 'datum', 'date', 'data',
  ];
  static const _valueDateHeaders = ['valuta', 'value date', 'date valeur'];
  static const _textHeaders = [
    'buchungstext', 'beschreibung', 'avisierungstext', 'description',
    'libellé', 'libelle', 'descrizione', 'mitteilung', 'zahlungszweck',
    'details', 'text', 'merchant', 'empfänger', 'partner', 'transaction',
  ];
  static const _amountHeaders = [
    'betrag', 'amount', 'montant', 'importo',
  ];
  static const _debitHeaders = [
    'belastung', 'lastschrift', 'debit', 'débit', 'addebito', 'soll',
  ];
  static const _creditHeaders = [
    'gutschrift', 'credit', 'crédit', 'accredito', 'haben',
  ];
  static const _balanceHeaders = ['saldo', 'balance', 'solde'];

  /// Parses [text]; throws [StatementFormatException] when it is not a
  /// statement Finora understands.
  static ParsedStatement parse(String text) {
    final cleaned = text.replaceFirst('﻿', '');
    final lines = cleaned
        .split(RegExp(r'\r\n|\n|\r'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) throw const StatementFormatException(StatementProblem.empty);
    final delimiter = _delimiter(lines.take(30));
    final table = [for (final line in lines) _split(line, delimiter)];

    // The header is the first row naming a date and an amount column.
    int? headerIndex;
    _Columns? columns;
    var sawDate = false;
    for (var index = 0; index < table.length && index < 40; index++) {
      final found = _Columns.find(table[index]);
      if (found.date != null) sawDate = true;
      if (found.date != null &&
          (found.amount != null || found.debit != null || found.credit != null)) {
        headerIndex = index;
        columns = found;
        break;
      }
    }
    if (columns == null || headerIndex == null) {
      throw StatementFormatException(
        sawDate ? StatementProblem.noAmount : StatementProblem.noHeader,
      );
    }

    final rows = <StatementRow>[];
    for (final cells in table.skip(headerIndex + 1)) {
      String cell(int? index) =>
          index == null || index >= cells.length ? '' : cells[index].trim();
      final date = parseDate(cell(columns.date));
      if (date == null) continue;
      int? cents;
      final amount = parseCents(cell(columns.amount));
      if (amount != null) {
        cents = amount;
      } else {
        final debit = parseCents(cell(columns.debit));
        final credit = parseCents(cell(columns.credit));
        if (debit != null && debit != 0) {
          cents = -debit.abs();
        } else if (credit != null) {
          cents = credit.abs();
        }
      }
      if (cents == null || cents == 0) continue;
      final text = [
        for (final index in columns.text)
          if (cell(index).isNotEmpty) cell(index),
      ].join(' ');
      final balance = parseCents(cell(columns.balance));
      rows.add(
        StatementRow(
          date: date,
          text: text.isEmpty ? '—' : text,
          amount: Money.cents(cents),
          balance: balance == null ? null : Money.cents(balance),
        ),
      );
    }
    if (rows.isEmpty) throw const StatementFormatException(StatementProblem.noRows);

    // Exports list the newest booking first or last; keep it to find the
    // closing balance, then sort oldest first.
    final newestFirst = rows.first.date.isAfter(rows.last.date);
    final newest = newestFirst ? rows.first : rows.last;
    final sorted = [...rows]..sort((a, b) => a.date.compareTo(b.date));
    return ParsedStatement(rows: sorted, closingBalance: newest.balance);
  }

  static String _delimiter(Iterable<String> lines) {
    var best = ';';
    var bestCount = -1;
    for (final candidate in [';', ',', '\t']) {
      final count = lines.fold<int>(
        0,
        (sum, line) => sum + candidate.allMatches(line).length,
      );
      if (count > bestCount) {
        best = candidate;
        bestCount = count;
      }
    }
    return best;
  }

  /// Splits one CSV line, honouring double quotes.
  static List<String> _split(String line, String delimiter) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        if (quoted && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (char == delimiter && !quoted) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }

  /// "1'234.50", "-1234,50", "1.234,50", "12.50-", "CHF 8.90" → cents.
  static int? parseCents(String raw) {
    var value = raw
        .replaceAll(RegExp(r"[\s '’`]"), '')
        .replaceAll(RegExp('[A-Za-z]'), '');
    if (value.isEmpty) return null;
    var negative = false;
    if (value.endsWith('-')) {
      negative = true;
      value = value.substring(0, value.length - 1);
    }
    if (value.startsWith('-') || value.startsWith('−')) {
      negative = true;
      value = value.substring(1);
    } else if (value.startsWith('+')) {
      value = value.substring(1);
    }
    final lastDot = value.lastIndexOf('.');
    final lastComma = value.lastIndexOf(',');
    String integer;
    var fraction = '';
    if (lastDot >= 0 && lastComma >= 0) {
      final decimal = lastDot > lastComma ? lastDot : lastComma;
      integer = value.substring(0, decimal).replaceAll(RegExp('[.,]'), '');
      fraction = value.substring(decimal + 1);
    } else if (lastDot >= 0 || lastComma >= 0) {
      final separator = lastDot >= 0 ? lastDot : lastComma;
      final digitsAfter = value.length - separator - 1;
      final single = value.indexOf(value[separator]) == separator;
      if (single && digitsAfter <= 2) {
        integer = value.substring(0, separator);
        fraction = value.substring(separator + 1);
      } else {
        integer = value.replaceAll(RegExp('[.,]'), '');
      }
    } else {
      integer = value;
    }
    if (!RegExp(r'^\d+$').hasMatch(integer.isEmpty ? '0' : integer) ||
        !RegExp(r'^\d{0,2}$').hasMatch(fraction)) {
      return null;
    }
    final cents =
        int.parse(integer.isEmpty ? '0' : integer) * 100 +
        int.parse(fraction.padRight(2, '0'));
    return negative ? -cents : cents;
  }

  /// "31.10.2026", "31.10.26", "2026-10-31", "31/10/2026", with or
  /// without a time.
  static DateTime? parseDate(String raw) {
    final value = raw.trim().split(RegExp(r'[\sT]')).first;
    var match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
    if (match != null) {
      return _date(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
    }
    match = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2}|\d{4})$')
        .firstMatch(value);
    if (match != null) {
      var year = int.parse(match[3]!);
      if (year < 100) year += 2000;
      return _date(year, int.parse(match[2]!), int.parse(match[1]!));
    }
    return null;
  }

  static DateTime? _date(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    return date.month == month ? date : null;
  }
}

class _Columns {
  _Columns({
    required this.date,
    required this.text,
    required this.amount,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory _Columns.find(List<String> cells) {
    final names = [
      for (final cell in cells) cell.trim().replaceAll('"', '').toLowerCase(),
    ];
    int? first(List<String> keys, {List<String> avoid = const []}) {
      for (final key in keys) {
        for (var index = 0; index < names.length; index++) {
          final name = names[index];
          if (name.contains(key) && !avoid.any(name.contains)) return index;
        }
      }
      return null;
    }

    final avoidForDate = [
      ...StatementParser._valueDateHeaders,
      ...StatementParser._balanceHeaders,
    ];
    final date =
        first(StatementParser._dateHeaders, avoid: avoidForDate) ??
        first(StatementParser._valueDateHeaders);
    final text = <int>[
      for (var index = 0; index < names.length; index++)
        if (StatementParser._textHeaders.any(names[index].contains) &&
            index != date)
          index,
    ];
    return _Columns(
      date: date,
      text: text.take(2).toList(),
      amount: first(
        StatementParser._amountHeaders,
        avoid: const ['einzelbetrag', 'saldo', 'balance', 'solde'],
      ),
      debit: first(StatementParser._debitHeaders),
      credit: first(StatementParser._creditHeaders),
      balance: first(StatementParser._balanceHeaders),
    );
  }

  final int? date;
  final List<int> text;
  final int? amount;
  final int? debit;
  final int? credit;
  final int? balance;
}
