import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/financial_repository.dart';
import 'package:finora/domain/market_data_repository.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/planning.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time. Overridable so tests and demos can freeze the clock.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Data sources. The UI only knows these contracts; the concrete
/// implementation is chosen in `app/bootstrap.dart`.
final financialRepositoryProvider = Provider<FinancialRepository>(
  (ref) => throw UnimplementedError(
    'Override financialRepositoryProvider in app/bootstrap.dart',
  ),
);

final marketDataRepositoryProvider = Provider<MarketDataRepository>(
  (ref) => throw UnimplementedError(
    'Override marketDataRepositoryProvider in app/bootstrap.dart',
  ),
);

final wealthTargetsProvider = Provider<WealthTargets>(
  (ref) => ref.watch(sessionProvider.select((session) => session.targets)),
);

/// Progress of every savings goal against today's balances.
final goalProgressProvider = FutureProvider<List<GoalProgress>>((ref) async {
  final goals = ref.watch(sessionProvider.select((session) => session.goals));
  final now = ref.watch(clockProvider)();
  final accounts = await ref.watch(accountsProvider.future);
  return [for (final goal in goals) GoalProgress.of(goal, accounts, now)];
});

/// The user's pension details, or the example profile until they add theirs.
final retirementProfileProvider = Provider<RetirementProfile>(
  (ref) =>
      ref.watch(sessionProvider.select((session) => session.retirement)) ??
      RetirementProfile.demo,
);

/// Whether the retirement figures are the user's own or the example.
final hasOwnRetirementProfileProvider = Provider<bool>(
  (ref) =>
      ref.watch(sessionProvider.select((session) => session.retirement)) !=
      null,
);

final retirementProjectionProvider = FutureProvider<RetirementProjection>((
  ref,
) async {
  final profile = ref.watch(retirementProfileProvider);
  final now = ref.watch(clockProvider)();
  final accounts = await ref.watch(accountsProvider.future);
  return RetirementProjection.of(
    profile,
    pillar3aBalance: Money.sum(
      accounts
          .where((account) => account.type.isRetirement)
          .map((account) => account.balance),
    ),
    now: now,
  );
});

/// Tax-return figures for a year, grouped like the Swiss forms.
final taxSummaryProvider = FutureProvider.family<TaxYearSummary, int>((
  ref,
  year,
) async {
  final data = await ref.watch(financialRepositoryProvider).getTaxYearData(year);
  return TaxYearSummary(
    data,
    pillar3aLimit: ref.watch(wealthTargetsProvider).pillar3aAnnualLimit,
  );
});

final institutionsProvider = FutureProvider<List<Institution>>(
  (ref) => ref.watch(financialRepositoryProvider).getInstitutions(),
);

final connectionsProvider = FutureProvider<List<InstitutionConnection>>(
  (ref) => ref.watch(financialRepositoryProvider).getConnections(),
);

final accountsProvider = FutureProvider<List<FinancialAccount>>(
  (ref) => ref.watch(financialRepositoryProvider).getAccounts(),
);

final accountAnalyticsProvider = FutureProvider.family<AccountAnalytics, String>(
  (ref, accountId) =>
      ref.watch(financialRepositoryProvider).getAccountAnalytics(accountId),
);

final transactionsProvider =
    FutureProvider.family<List<FinancialTransaction>, String?>(
      (ref, accountId) => ref
          .watch(financialRepositoryProvider)
          .getTransactions(accountId: accountId),
    );

/// Educational themes for a language code such as `de`.
final marketThemesProvider = FutureProvider.family<List<MarketTheme>, String>(
  (ref, languageCode) => ref
      .watch(marketDataRepositoryProvider)
      .getSwissMarketThemes(languageCode: languageCode),
);

/// Net worth, allocation and history, always derived from the accounts so
/// the dashboard can never disagree with the account list.
final overviewProvider = FutureProvider<FinancialOverview>((ref) async {
  final repository = ref.watch(financialRepositoryProvider);
  final now = ref.watch(clockProvider)();
  final accounts = await ref.watch(accountsProvider.future);
  final analytics = await Future.wait([
    for (final account in accounts)
      ref.watch(accountAnalyticsProvider(account.id).future),
  ]);

  // Sum every account's monthly closing balance into a net-worth series.
  final totalsByMonth = <DateTime, Money>{};
  for (final item in analytics) {
    for (final point in item.balanceHistory) {
      totalsByMonth[point.month] =
          (totalsByMonth[point.month] ?? Money.zero) + point.balance;
    }
  }
  final months = totalsByMonth.keys.toList()..sort();
  final history = [
    for (final month in months)
      BalanceHistoryPoint(month: month, balance: totalsByMonth[month]!),
  ];

  final monthlySpending = Money.sum([
    for (var index = 0; index < accounts.length; index++)
      if (accounts[index].type == FinancialProductType.currentAccount)
        analytics[index].monthlySpending,
  ]);

  return FinancialOverview.fromAccounts(
    accounts,
    history: history,
    monthlySpending: monthlySpending,
    pillar3aContributionsThisYear: await repository.getPillar3aContributions(
      year: now.year,
    ),
  );
});

/// Things worth the user's attention, shown behind the notification bell.
final alertsProvider = FutureProvider<List<FinoraAlert>>((ref) async {
  final session = ref.watch(sessionProvider);
  final now = ref.watch(clockProvider)();
  final institutions = await ref.watch(institutionsProvider.future);
  final connections = await ref.watch(connectionsProvider.future);
  final accounts = await ref.watch(accountsProvider.future);

  String nameOf(String institutionId) =>
      institutions
          .where((institution) => institution.id == institutionId)
          .firstOrNull
          ?.name ??
      institutionId;

  final alerts = <FinoraAlert>[];
  if (session.dataHealthAlerts) {
    for (final connection in connections) {
      final kind = switch (connection.status) {
        ConnectionStatus.actionRequired => AlertKind.consentRequired,
        ConnectionStatus.stale => AlertKind.staleConnection,
        ConnectionStatus.manual
            when now.difference(connection.lastSyncedAt).inDays >= 30 =>
          AlertKind.manualValueOutdated,
        _ => null,
      };
      if (kind == null) continue;
      alerts.add(
        FinoraAlert(
          kind: kind,
          subject: nameOf(connection.institutionId),
          route: '/institution/${connection.institutionId}',
        ),
      );
    }
  }

  for (final account in accounts) {
    if (account.type != FinancialProductType.currentAccount) continue;
    final analytics = await ref.watch(
      accountAnalyticsProvider(account.id).future,
    );
    for (final payment in analytics.recurringPayments) {
      final daysUntilDue = payment.nextDueAt.difference(now).inDays;
      if (daysUntilDue >= 0 && daysUntilDue <= 7) {
        alerts.add(
          FinoraAlert(
            kind: AlertKind.billDue,
            subject: payment.merchant,
            bill: payment.category,
            amount: payment.amount.abs(),
            daysUntilDue: daysUntilDue,
            route: '/account/${account.id}',
          ),
        );
      }
    }
  }
  return alerts;
});

/// Refreshes every source and recomputes everything that depends on it.
Future<void> refreshFinancialData(WidgetRef ref) async {
  await ref.read(financialRepositoryProvider).refresh();
  ref
    ..invalidate(connectionsProvider)
    ..invalidate(accountsProvider)
    ..invalidate(accountAnalyticsProvider)
    ..invalidate(transactionsProvider)
    ..invalidate(overviewProvider)
    ..invalidate(taxSummaryProvider);
}
