import 'package:finora/domain/models.dart';
import 'package:intl/intl.dart';

/// "Hide amounts" mode: when on, every formatted amount is masked so the
/// app can be shown in public. `FinoraApp` keeps it in sync with the
/// session.
abstract final class AmountPrivacy {
  static bool hidden = false;
}

String _masked(Money money) => '${money.currency} •••';

/// Swiss-formatted amount, e.g. `CHF 12'480.40`.
String formatMoney(Money money, {bool signed = false}) {
  if (AmountPrivacy.hidden) return _masked(money);
  final formatter = NumberFormat.currency(
    locale: 'de_CH',
    symbol: money.currency,
    decimalDigits: 2,
  );
  final value = formatter.format(money.amount.abs()).replaceAll('’', "'");
  if (!signed || money.isZero) return value;
  return '${money.isNegative ? '−' : '+'} $value';
}

/// Whole francs, e.g. `CHF 3'250`, for estimates that should not look
/// more precise than they are.
String formatMoneyWhole(Money money) {
  if (AmountPrivacy.hidden) return _masked(money);
  final formatter = NumberFormat.currency(
    locale: 'de_CH',
    symbol: money.currency,
    decimalDigits: 0,
  );
  return formatter.format(money.amount.abs()).replaceAll('’', "'");
}

/// Short amount for tight layouts, e.g. `CHF 44.8k` or `CHF 1.2M`.
String formatCompactMoney(Money money, {bool signed = false}) {
  if (AmountPrivacy.hidden) return _masked(money);
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

// Month names follow `Intl.defaultLocale`, which `FinoraApp` keeps in sync
// with the active app language.

/// Three-letter month for chart axes, e.g. `OCT`.
String formatMonthShort(DateTime month) =>
    DateFormat.MMM().format(month).toUpperCase();

/// Full month name for section headers, e.g. `October 2026`.
String formatMonthYear(DateTime month) => DateFormat.yMMMM().format(month);
