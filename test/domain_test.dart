import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/shared/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('Money', () {
    test('adds without floating-point drift', () {
      expect(Money(0.1) + Money(0.2), Money(0.3));
      expect(Money.sum([Money(19.99), Money(0.01)]), const Money.cents(2000));
    });

    test('supports negation and absolute values', () {
      const debt = Money.cents(-184550);
      expect(debt.isNegative, isTrue);
      expect(debt.abs(), const Money.cents(184550));
      expect(-debt, const Money.cents(184550));
    });
  });

  group('FinancialOverview', () {
    test('derives totals from accounts, netting liabilities', () {
      final overview = FinancialOverview.fromAccounts(const [
        FinancialAccount(
          id: 'a',
          institutionId: 'x',
          name: 'Current',
          type: FinancialProductType.currentAccount,
          balance: Money.cents(100000),
          maskedIdentifier: '',
          monthlyChange: Money.zero,
        ),
        FinancialAccount(
          id: 'b',
          institutionId: 'x',
          name: 'ETF',
          type: FinancialProductType.investments,
          balance: Money.cents(300000),
          maskedIdentifier: '',
          monthlyChange: Money.zero,
        ),
        FinancialAccount(
          id: 'c',
          institutionId: 'x',
          name: 'Card',
          type: FinancialProductType.creditCard,
          balance: Money.cents(-50000),
          maskedIdentifier: '',
          monthlyChange: Money.zero,
        ),
      ]);
      expect(overview.cash, const Money.cents(100000));
      expect(overview.assets, const Money.cents(400000));
      expect(overview.liabilities, const Money.cents(50000));
      expect(overview.total, const Money.cents(350000));
      expect(overview.share(overview.investments), .75);
    });

    test('computes change rates from history', () {
      final overview = FinancialOverview.fromAccounts(
        const [],
        history: [
          BalanceHistoryPoint(
            month: DateTime(2026, 9),
            balance: const Money.cents(100000),
          ),
          BalanceHistoryPoint(
            month: DateTime(2026, 10),
            balance: const Money.cents(103100),
          ),
        ],
      );
      expect(overview.monthlyChangeRate, closeTo(.031, 1e-9));
      expect(overview.periodChange, const Money.cents(3100));
    });
  });

  group('UserSession', () {
    test('survives a round trip through storage', () {
      final session = UserSession.demo().copyWith(dataHealthAlerts: false);
      final restored = UserSession.decode(session.encode())!;
      expect(restored.email, session.email);
      expect(restored.products, session.products);
      expect(restored.connectedInstitutionIds, session.connectedInstitutionIds);
      expect(restored.onboardingCompleted, isTrue);
      expect(restored.dataHealthAlerts, isFalse);
    });

    test('ignores corrupt or unknown stored values', () {
      expect(UserSession.decode('not json'), isNull);
      expect(UserSession.decode(null), isNull);
      final restored = UserSession.decode(
        '{"connectedInstitutionIds":["ubs","unknown-bank"]}',
      )!;
      expect(restored.connectedInstitutionIds, {'ubs'});
    });

    test('derives a display name and initials from the e-mail', () {
      const session = UserSession(email: 'anna.muster@example.ch');
      expect(session.displayName, 'Anna');
      expect(session.initials, 'AM');
    });
  });

  group('Demo data follows the session', () {
    test('only selected institutions and products appear', () async {
      final container = createTestContainer(
        session: const UserSession(
          onboardingCompleted: true,
          products: {
            FinancialProductType.currentAccount,
            FinancialProductType.savings,
          },
          connectedInstitutionIds: {'postfinance'},
        ),
      );
      final accounts = await container.read(accountsProvider.future);
      expect(accounts.map((account) => account.institutionId).toSet(), {
        'postfinance',
      });

      final overview = await container.read(overviewProvider.future);
      expect(overview.total, Money.sum(accounts.map((a) => a.balance)));
      expect(overview.history.length, 6);
      expect(overview.history.last.balance, overview.total);
    });

    test('disconnecting an institution updates the overview', () async {
      final container = createTestContainer();
      final before = await container.read(overviewProvider.future);

      container.read(sessionProvider.notifier).disconnect('swissquote');
      final after = await container.read(overviewProvider.future);

      expect(
        before.investments - after.investments,
        const Money.cents(4230000),
      );
    });

    test('completing onboarding is persisted', () async {
      final store = InMemorySessionStore();
      final container = createTestContainer(store: store);
      container
          .read(sessionProvider.notifier)
          .completeOnboarding(
            email: 'demo@finora.ch',
            products: {FinancialProductType.currentAccount},
            connectedInstitutionIds: {'ubs'},
          );
      expect(store.load()?.onboardingCompleted, isTrue);
      expect(store.load()?.connectedInstitutionIds, {'ubs'});
    });

    test('Pillar 3a contributions are capped by the annual limit', () async {
      final container = createTestContainer();
      final overview = await container.read(overviewProvider.future);
      // October in the test clock: ten monthly CHF 605 contributions.
      expect(overview.pillar3aContributionsThisYear, const Money.cents(605000));
      expect(
        overview.pillar3aContributionsThisYear.compareTo(
          const WealthTargets().pillar3aAnnualLimit,
        ),
        lessThanOrEqualTo(0),
      );
    });
  });

  group('Formatters', () {
    test('describe connection freshness', () {
      final now = DateTime(2026, 10, 23, 12);
      expect(
        formatSyncTime(now.subtract(const Duration(minutes: 4)), now),
        'Updated 4 min ago',
      );
      expect(
        formatSyncTime(now.subtract(const Duration(hours: 26)), now),
        'Updated yesterday',
      );
    });

    test('compact amounts keep sign and unit', () {
      expect(formatCompactMoney(const Money.cents(4482040)), 'CHF 44.8k');
      expect(
        formatCompactMoney(const Money.cents(-184550)),
        '− CHF 1.8k',
      );
      expect(
        formatCompactMoney(const Money.cents(90000), signed: true),
        '+ CHF 900',
      );
    });
  });
}
