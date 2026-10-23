import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:finora/shared/formatters.dart';

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
      _ when institution.productTypes.contains(
        FinancialProductType.currentAccount,
      ) =>
        Icons.account_balance_rounded,
      _ when institution.productTypes.contains(
        FinancialProductType.investments,
      ) =>
        Icons.show_chart_rounded,
      _ when institution.productTypes.contains(FinancialProductType.pillar3a) =>
        Icons.savings_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };
    return Semantics(
      label: context.l10n.institutionLogo(institution.name),
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
                color: Color(0x1A272829),
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
    final label = context.l10n.connectionStatus(status);
    final (color, icon) = switch (status) {
      ConnectionStatus.connected => (finoraGreen, Icons.check_circle),
      ConnectionStatus.stale => (finoraWarning, Icons.schedule),
      ConnectionStatus.actionRequired => (finoraDanger, Icons.error),
      ConnectionStatus.manual => (finoraSlate, Icons.edit_note),
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

class TransactionTile extends ConsumerWidget {
  const TransactionTile({required this.transaction, super.key});
  final FinancialTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final l10n = context.l10n;
    final positive = !transaction.amount.isNegative;
    final (icon, accent) = switch (transaction.category) {
      TransactionCategory.income => (Icons.south_west, finoraGreen),
      TransactionCategory.transport => (Icons.train_outlined, finoraSlate),
      TransactionCategory.groceries => (
        Icons.shopping_basket_outlined,
        finoraBlue,
      ),
      TransactionCategory.utilities => (Icons.receipt_long_outlined, finoraBlue),
      TransactionCategory.insurance => (
        Icons.health_and_safety_outlined,
        finoraSlate,
      ),
      TransactionCategory.dining => (Icons.restaurant_outlined, finoraBlue),
      TransactionCategory.housing => (Icons.home_outlined, finoraInk),
      TransactionCategory.shopping ||
      TransactionCategory.other => (Icons.shopping_bag_outlined, finoraSilver),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: .13),
        foregroundColor: finoraAccessibleAccent(accent),
        child: Icon(icon, size: 20),
      ),
      title: Text(
        transaction.merchant,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${l10n.transactionCategory(transaction.category)} · ${l10n.relativeDay(transaction.bookedAt, now)}',
        style: const TextStyle(color: finoraMutedInk, fontSize: 12),
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

/// Small rounded label used for gains, losses and statuses.
class ValuePill extends StatelessWidget {
  const ValuePill({required this.label, required this.color, super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            color: finoraAccessibleAccent(color),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Full-screen message for a route whose item no longer exists.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: Colors.transparent),
    body: Center(child: Text(label)),
  );
}
