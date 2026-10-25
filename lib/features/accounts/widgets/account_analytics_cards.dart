import 'dart:math' as math;

import 'package:finora/app/theme.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';

class BalanceEvolutionCard extends StatelessWidget {
  const BalanceEvolutionCard({required this.analytics, required this.months, super.key});
  final AccountAnalytics analytics;
  final int months;

  @override
  Widget build(BuildContext context) {
    final requestedPoints = months == 1 ? 2 : months;
    final pointCount = math.min(
      requestedPoints,
      analytics.balanceHistory.length,
    );
    final points = analytics.balanceHistory.sublist(
      analytics.balanceHistory.length - pointCount,
    );
    final change = points.last.balance - points.first.balance;
    final positive = !change.isNegative;
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.balanceEvolution,
                        style: const TextStyle(
                          color: finoraInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.balanceEvolutionSubtitle,
                        style: const TextStyle(color: finoraMutedInk),
                      ),
                    ],
                  ),
                ),
                ValuePill(
                  label: formatCompactMoney(change, signed: true),
                  color: positive ? finoraGreen : finoraDanger,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Semantics(
              label: (positive ? l10n.balanceTrendUp : l10n.balanceTrendDown)(
                formatMoney(change.abs()),
                l10n.monthsCount(months),
                formatMoney(points.last.balance),
              ),
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 128,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _BalanceHistoryPainter(points: points),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            MonthAxis(months: [for (final point in points) point.month]),
          ],
        ),
      ),
    );
  }
}

class CashFlowCard extends StatelessWidget {
  const CashFlowCard({required this.analytics, required this.months, super.key});
  final AccountAnalytics analytics;
  final int months;

  @override
  Widget build(BuildContext context) {
    final savingsRate = (analytics.savingsRate * 100).round();
    final l10n = context.l10n;
    final pointCount = math.min(months, analytics.cashFlowHistory.length);
    final points = analytics.cashFlowHistory.sublist(
      analytics.cashFlowHistory.length - pointCount,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.incomeVsSpending,
                    style: const TextStyle(
                      color: finoraInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ValuePill(label: l10n.keptPercent(savingsRate), color: finoraBlue),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _CashFlowMetric(
                    label: l10n.incomeLabel.toUpperCase(),
                    value: formatMoney(analytics.monthlyIncome),
                    color: finoraGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CashFlowMetric(
                    label: l10n.spendingLabel.toUpperCase(),
                    value: formatMoney(analytics.monthlySpending),
                    color: finoraBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              label: l10n.cashFlowSemantics(
                l10n.monthsCount(months),
                formatMoney(analytics.monthlyIncome),
                formatMoney(analytics.monthlySpending),
              ),
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: CustomPaint(painter: _CashFlowPainter(points: points)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final point in points)
                  Text(
                    formatMonthShort(point.month),
                    style: const TextStyle(
                      color: finoraMutedInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              analytics.monthlyNet.isNegative
                  ? l10n.overspentThisMonth(formatMoney(analytics.monthlyNet.abs()))
                  : l10n.availableAfterSpending(
                      formatMoney(analytics.monthlyNet, signed: true),
                    ),
              style: const TextStyle(
                color: finoraInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpendingCategoriesCard extends StatelessWidget {
  const SpendingCategoriesCard({required this.analytics, super.key});
  final AccountAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final total = Money.sum(
      analytics.spendingCategories.map((category) => category.amount),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.whereMoneyWent,
              style: const TextStyle(
                color: finoraInk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.categorisedThisMonth(formatMoney(total)),
              style: const TextStyle(color: finoraMutedInk),
            ),
            const SizedBox(height: 20),
            for (
              var index = 0;
              index < analytics.spendingCategories.length;
              index++
            ) ...[
              _SpendingCategoryRow(
                category: analytics.spendingCategories[index],
                total: total,
              ),
              if (index != analytics.spendingCategories.length - 1)
                const SizedBox(height: 15),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpendingCategoryRow extends StatelessWidget {
  const _SpendingCategoryRow({required this.category, required this.total});
  final SpendingCategory category;
  final Money total;

  @override
  Widget build(BuildContext context) {
    final share = total.isZero ? 0.0 : category.amount.cents / total.cents;
    final percent = (share * 100).round();
    final color = Color(category.colorValue);
    return Semantics(
      label:
          context.l10n.categorySemantics(
            context.l10n.transactionCategory(category.category),
            formatMoney(category.amount),
            percent,
          ),
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.l10n.transactionCategory(category.category),
                    style: const TextStyle(
                      color: finoraInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  formatMoney(category.amount),
                  style: const TextStyle(
                    color: finoraInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 34,
                  child: Text(
                    '$percent%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: finoraMutedInk,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(finoraRadiusSmall),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 7,
                backgroundColor: color.withValues(alpha: .1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowMetric extends StatelessWidget {
  const _CashFlowMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = finoraAccessibleAccent(color);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(finoraRadiusControl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: finoraInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecurringPaymentsCard extends StatelessWidget {
  const RecurringPaymentsCard({
    required this.analytics,
    required this.showAll,
    required this.now,
    super.key,
  });
  final AccountAnalytics analytics;
  final bool showAll;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final payments = showAll
        ? analytics.recurringPayments
        : analytics.recurringPayments.take(3).toList();
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.detectedCount(
                      analytics.recurringPayments.length,
                    ),
                    style: const TextStyle(
                      color: finoraInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  context.l10n.perMonth(formatMoney(analytics.recurringTotal)),
                  style: const TextStyle(
                    color: finoraBlueText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < payments.length; index++) ...[
            _RecurringPaymentTile(payment: payments[index], now: now),
            if (index != payments.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _RecurringPaymentTile extends StatelessWidget {
  const _RecurringPaymentTile({required this.payment, required this.now});
  final RecurringPayment payment;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final icon = switch (payment.category) {
      BillCategory.healthInsurance ||
      BillCategory.householdInsurance => Icons.health_and_safety_outlined,
      BillCategory.phoneInternet => Icons.wifi,
      BillCategory.membership => Icons.fitness_center,
      BillCategory.electricity => Icons.bolt_outlined,
      BillCategory.streaming ||
      BillCategory.radioTvFee => Icons.subscriptions_outlined,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: finoraSoftBlue,
        foregroundColor: finoraBlue,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        payment.merchant,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${l10n.billCategory(payment.category)} · ${l10n.dueDate(payment.nextDueAt, now)}',
        style: const TextStyle(color: finoraMutedInk, fontSize: 12),
      ),
      trailing: Text(
        formatMoney(payment.amount.abs()),
        style: const TextStyle(color: finoraInk, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BalanceHistoryPainter extends CustomPainter {
  const _BalanceHistoryPainter({required this.points});
  final List<BalanceHistoryPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = points.map((point) => point.balance.amount).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1.0, maxValue - minValue);
    const topPadding = 10.0;
    const bottomPadding = 8.0;
    final graphHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = finoraBorder
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = topPadding + graphHeight * index / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = size.width * index / (points.length - 1);
      final normalized = (points[index].balance.amount - minValue) / range;
      final y = topPadding + graphHeight * (1 - normalized);
      final offset = Offset(x, y);
      offsets.add(offset);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            finoraBlue.withValues(alpha: .22),
            finoraBlue.withValues(alpha: .01),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = finoraBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(offsets.last, 5, Paint()..color = finoraBlue);
    canvas.drawCircle(offsets.last, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BalanceHistoryPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _CashFlowPainter extends CustomPainter {
  const _CashFlowPainter({required this.points});
  final List<CashFlowPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maximum = points
        .expand((point) => [point.income.amount, point.spending.amount])
        .reduce(math.max);
    if (maximum <= 0) return;
    final groupWidth = size.width / points.length;
    final barWidth = math.min(11.0, groupWidth * .22);
    final baseline = size.height;
    final background = Paint()..color = finoraCanvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      background,
    );

    for (var index = 0; index < points.length; index++) {
      final center = groupWidth * index + groupWidth / 2;
      final incomeHeight =
          size.height * points[index].income.amount / maximum * .86;
      final spendingHeight =
          size.height * points[index].spending.amount / maximum * .86;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center - barWidth - 2,
            baseline - incomeHeight,
            barWidth,
            incomeHeight,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = finoraGreen,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center + 2,
            baseline - spendingHeight,
            barWidth,
            spendingHeight,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = finoraBlue,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CashFlowPainter oldDelegate) =>
      oldDelegate.points != points;
}
