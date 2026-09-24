import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatMoney(Money money, {bool signed = false}) {
  final formatter = NumberFormat.currency(
    locale: 'de_CH',
    symbol: money.currency,
    decimalDigits: 2,
  );
  final value = formatter.format(money.amount.abs()).replaceAll('’', "'");
  if (!signed || money.amount == 0) return value;
  return '${money.amount > 0 ? '+' : '−'} $value';
}

class FinoraPage extends StatelessWidget {
  const FinoraPage({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 32),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class InstitutionBadge extends StatelessWidget {
  const InstitutionBadge({
    required this.institution,
    this.size = 46,
    super.key,
  });
  final Institution institution;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (institution.id) {
      'ubs' => Icons.key_rounded,
      'zkb' => Icons.account_balance_rounded,
      'swissquote' => Icons.show_chart_rounded,
      'frankly' => Icons.savings_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };
    return Semantics(
      label: '${institution.name} institution logo',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color(institution.colorValue),
            borderRadius: BorderRadius.circular(size * .28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A17366B),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: size * .48),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.action, super.key});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: .35,
                fontWeight: FontWeight.w800,
                color: finoraInk,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      ConnectionStatus.connected => (
        'Healthy',
        finoraGreen,
        Icons.check_circle,
      ),
      ConnectionStatus.stale => (
        'Needs refresh',
        const Color(0xFF9A5B00),
        Icons.schedule,
      ),
      ConnectionStatus.actionRequired => (
        'Action needed',
        Colors.red.shade700,
        Icons.error,
      ),
      ConnectionStatus.manual => (
        'Manual',
        const Color(0xFF5D6670),
        Icons.edit_note,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, super.key});
  final FinancialTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.amount.amount > 0;
    final icon = switch (transaction.category) {
      'Income' => Icons.south_west,
      'Transport' => Icons.train_outlined,
      'Groceries' => Icons.shopping_basket_outlined,
      'Utilities' => Icons.receipt_long_outlined,
      _ => Icons.shopping_bag_outlined,
    };
    final accent = switch (transaction.category) {
      'Income' => finoraGreen,
      'Transport' => finoraYellow,
      'Groceries' => finoraAqua,
      'Utilities' => finoraBlue,
      _ => finoraPink,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: .13),
        foregroundColor: accent,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        transaction.merchant,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${transaction.category} · ${transaction.dateLabel}',
        style: const TextStyle(color: Color(0xFF8A98AB), fontSize: 12),
      ),
      trailing: Text(
        formatMoney(transaction.amount, signed: true),
        style: TextStyle(
          color: positive ? finoraGreen : finoraInk,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
