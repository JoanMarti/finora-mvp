import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/simulators.dart';
import 'package:finora/features/simulators/simulator_widgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Can I afford a home?" with the rules Swiss banks apply.
class HomeBuyingScreen extends ConsumerStatefulWidget {
  const HomeBuyingScreen({super.key});

  @override
  ConsumerState<HomeBuyingScreen> createState() => _HomeBuyingScreenState();
}

class _HomeBuyingScreenState extends ConsumerState<HomeBuyingScreen> {
  HomeAffordability? _inputs;
  Money _price = Money.zero;

  /// Starts from the user's own figures: salary from the retirement
  /// profile, cash and Pillar 3a from the connected accounts.
  HomeAffordability _defaults() {
    final overview = ref.read(overviewProvider).value;
    final profile = ref.read(retirementProfileProvider);
    return HomeAffordability(
      grossYearlyIncome: profile.annualSalary,
      cashEquity: overview?.cash ?? Money.zero,
      pillar3a: overview?.retirement ?? Money.zero,
      pensionFundWithdrawal: Money.zero,
    );
  }

  HomeAffordability _copy({
    Money? income,
    Money? cash,
    Money? pillar3a,
    Money? pension,
  }) {
    final current = _inputs!;
    return HomeAffordability(
      grossYearlyIncome: income ?? current.grossYearlyIncome,
      cashEquity: cash ?? current.cashEquity,
      pillar3a: pillar3a ?? current.pillar3a,
      pensionFundWithdrawal: pension ?? current.pensionFundWithdrawal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overview = ref.watch(overviewProvider);
    if (overview.isLoading && _inputs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final inputs = _inputs ??= _defaults();
    final (maxPrice, limit) = inputs.maxPrice;
    final limitText = switch (limit) {
      AffordabilityLimit.equity => l10n.homeLimitEquity,
      AffordabilityLimit.hardEquity => l10n.homeLimitHardEquity,
      AffordabilityLimit.income => l10n.homeLimitIncome,
    };
    final pensionBalance = ref.watch(retirementProfileProvider).pensionFundBalance;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.homeTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            HeroCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeMaxPrice,
                      style: const TextStyle(color: finoraSilver),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatMoneyWhole(maxPrice),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      limitText,
                      style: const TextStyle(
                        color: finoraSilver,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SectionTitle(l10n.homeYourFiguresSection),
            MoneyField(
              label: l10n.homeIncomeLabel,
              helper: l10n.homeIncomeHelp,
              value: inputs.grossYearlyIncome,
              onChanged: (value) => setState(() => _inputs = _copy(income: value)),
            ),
            MoneyField(
              label: l10n.homeCashLabel,
              helper: l10n.homeCashHelp,
              value: inputs.cashEquity,
              onChanged: (value) => setState(() => _inputs = _copy(cash: value)),
            ),
            MoneyField(
              label: l10n.homePillar3aLabel,
              value: inputs.pillar3a,
              onChanged: (value) =>
                  setState(() => _inputs = _copy(pillar3a: value)),
            ),
            MoneyField(
              label: l10n.homePensionLabel,
              helper: l10n.homePensionHelp(formatMoneyWhole(pensionBalance)),
              value: inputs.pensionFundWithdrawal,
              onChanged: (value) =>
                  setState(() => _inputs = _copy(pension: value)),
            ),
            SectionTitle(l10n.homeCheckSection),
            MoneyField(
              label: l10n.homePriceLabel,
              value: _price,
              onChanged: (value) => setState(() => _price = value),
            ),
            if (!_price.isZero) _PriceCheck(inputs: inputs, price: _price),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/offers'),
              icon: const Icon(Icons.home_work_outlined),
              label: Text(l10n.homeCompareMortgages),
            ),
            SimulatorNote(l10n.homeDisclaimer),
          ],
        ),
      ),
    );
  }
}

class _PriceCheck extends StatelessWidget {
  const _PriceCheck({required this.inputs, required this.price});
  final HomeAffordability inputs;
  final Money price;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final check = inputs.check(price);
    final equityOk =
        inputs.equity.cents >= inputs.equityNeededFor(price).cents &&
        inputs.hardEquity.cents >=
            (price * SwissMortgageRules.minHardEquityShare).cents;
    final incomeOk = inputs.fits(price);
    final ok = equityOk && incomeOk;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.error_outline,
                  color: ok ? finoraGreen : finoraWarning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok ? l10n.homeFits : l10n.homeDoesNotFit,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ResultRow(
              label: l10n.homeEquityNeeded,
              value: formatMoneyWhole(inputs.equityNeededFor(price)),
            ),
            ResultRow(
              label: l10n.homeMortgage,
              value:
                  '${formatMoneyWhole(check.mortgage)} · ${(check.loanToValue * 100).round()}%',
            ),
            ResultRow(
              label: l10n.homeMonthlyCost,
              value: formatMoneyWhole(check.monthlyCost),
            ),
            ResultRow(
              label: l10n.homeCostShare,
              value: '${(check.costShare * 100).round()}%',
              emphasised: true,
            ),
            if (!incomeOk)
              SimulatorNote(
                l10n.homeIncomeNeeded(
                  formatMoneyWhole(inputs.incomeNeededFor(price)),
                ),
              ),
            if (!equityOk)
              SimulatorNote(
                l10n.homeEquityShort(
                  formatMoneyWhole(inputs.equityNeededFor(price)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
