import 'package:finora/domain/models.dart';
import 'package:intl/intl.dart';

/// Swiss-formatted amount, e.g. `CHF 12'480.40`.
String formatMoney(Money money, {bool signed = false}) {
  final formatter = NumberFormat.currency(
    locale: 'de_CH',
    symbol: money.currency,
    decimalDigits: 2,
  );
  final value = formatter.format(money.amount.abs()).replaceAll('’', "'");
  if (!signed || money.isZero) return value;
  return '${money.isNegative ? '−' : '+'} $value';
}

/// Short amount for tight layouts, e.g. `CHF 44.8k` or `CHF 1.2M`.
String formatCompactMoney(Money money, {bool signed = false}) {
  final absolute = money.amount.abs();
  final String number;
  if (absolute >= 1000000) {
    number = '${(absolute / 1000000).toStringAsFixed(1)}M';
  } else if (absolute >= 1000) {
    number = '${(absolute / 1000).toStringAsFixed(1)}k';
  } else {
    number = absolute.toStringAsFixed(0);
  }
  final sign = money.isNegative ? '−' : (signed && !money.isZero ? '+' : '');
  return '${sign.isEmpty ? '' : '$sign '}${money.currency} $number';
}

/// `+3.1%` / `−0.4%` from a fraction such as 0.031.
String formatPercentChange(double rate) {
  final percent = (rate * 100).abs().toStringAsFixed(1);
  return '${rate < 0 ? '−' : '+'}$percent%';
}

/// Three-letter month for chart axes, e.g. `OCT`.
String formatMonthShort(DateTime month) =>
    DateFormat.MMM().format(month).toUpperCase();

/// Full month name for section headers, e.g. `October 2026`.
String formatMonthYear(DateTime month) => DateFormat.yMMMM().format(month);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// `Today`, `Yesterday` or `12 Oct`.
String formatRelativeDay(DateTime date, DateTime now) {
  if (_isSameDay(date, now)) return 'Today';
  if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
    return 'Yesterday';
  }
  return DateFormat('d MMM').format(date);
}

/// `Due today`, `Due tomorrow` or `Due 28 Oct`.
String formatDueDate(DateTime due, DateTime now) {
  if (_isSameDay(due, now)) return 'Due today';
  if (_isSameDay(due, now.add(const Duration(days: 1)))) return 'Due tomorrow';
  return 'Due ${DateFormat('d MMM').format(due)}';
}

/// How fresh a connection is, e.g. `Updated 4 min ago`.
String formatSyncTime(DateTime syncedAt, DateTime now) {
  final age = now.difference(syncedAt);
  if (age.inMinutes < 1) return 'Updated just now';
  if (age.inMinutes < 60) return 'Updated ${age.inMinutes} min ago';
  if (age.inHours < 24) return 'Updated ${age.inHours} h ago';
  if (age.inDays == 1) return 'Updated yesterday';
  return 'Updated ${age.inDays} days ago';
}
