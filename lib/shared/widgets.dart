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
            borderRadius: BorderRadius.circular(size * .22),
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
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  letterSpacing: -.3,
                  fontWeight: FontWeight.w800,
                  color: finoraInk,
                ),
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
        borderRadius: BorderRadius.circular(finoraRadiusSmall),
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
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(finoraRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: finoraAccessibleAccent(color),
            fontSize: 12,
            fontWeight: FontWeight.w700,
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

/// Two-column grid of small label / value tiles.
class KeyFigureGrid extends StatelessWidget {
  const KeyFigureGrid({required this.figures, super.key});
  final List<(String, String)> figures;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        for (final (label, value) in figures)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: finoraMutedInk,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Month labels under a chart, placed under their data points. With many
/// months only about six labels are shown, always including the latest.
class MonthAxis extends StatelessWidget {
  const MonthAxis({required this.months, super.key});
  final List<DateTime> months;

  @override
  Widget build(BuildContext context) {
    final count = months.length;
    if (count == 0) return const SizedBox.shrink();
    final step = count <= 7 ? 1 : ((count - 1) / 5).ceil();
    return SizedBox(
      height: 14,
      child: Stack(
        children: [
          for (var index = 0; index < count; index++)
            if ((count - 1 - index) % step == 0)
              Align(
                alignment: Alignment(
                  count == 1 ? 0 : -1 + 2 * index / (count - 1),
                  0,
                ),
                child: Text(
                  formatMonthShort(months[index]),
                  style: TextStyle(
                    color: index == count - 1 ? finoraBlueText : finoraMutedInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Dark gradient card for summaries at the top of detail screens. Texts
/// inside use light colours (white, [finoraSilver]).
class HeroCard extends StatelessWidget {
  const HeroCard({
    required this.child,
    this.gradient = finoraInkGradient,
    super.key,
  });
  final Widget child;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(finoraRadius),
      boxShadow: finoraShadow,
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// Icon on a soft tinted circle, used for lists, tools and actions.
class TonalIcon extends StatelessWidget {
  const TonalIcon(
    this.icon, {
    this.color = finoraBlueText,
    this.background = finoraSoftBlue,
    this.size = 44,
    super.key,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(size * .22),
    ),
    child: Icon(icon, color: color, size: size * .5),
  );
}
