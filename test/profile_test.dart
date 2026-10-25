import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/profile.dart';
import 'package:finora/domain/user_session.dart';
import 'package:finora/features/profile/about_you_screen.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('Profile', () {
    test('round-trips and measures completeness', () {
      const empty = UserProfile();
      expect(empty.completeness, 0);
      expect(empty.isEmpty, isTrue);

      final demo = UserSession.demo().profile;
      expect(demo.completeness, 1);
      final restored = UserSession.decode(UserSession.demo().encode())!.profile;
      expect(restored.canton, Canton.zh);
      expect(restored.rentDeposit, const Money.cents(660000));
      expect(restored.interests, {Interest.buyHome, Interest.investing});

      const half = UserProfile(
        birthYear: 1990,
        canton: Canton.be,
        employment: Employment.employee,
        housing: Housing.renting,
      );
      expect(half.completeness, closeTo(4 / 9, .001));
      expect(half.ageAt(DateTime(2026, 10, 23)), 36);
    });

    test('the risk check places answers on three profiles', () {
      expect(RiskQuestionnaire.score([0, 0, 1]), RiskProfile.cautious);
      expect(RiskQuestionnaire.score([1, 1, 1]), RiskProfile.balanced);
      expect(RiskQuestionnaire.score([2, 2, 1]), RiskProfile.dynamic);
    });

    test('self-employed people get the larger Pillar 3a limit', () {
      const employeeLimit = Money.cents(725800);
      const selfEmployed = UserProfile(
        employment: Employment.selfEmployed,
        grossIncome: Money.cents(10000000),
      );
      expect(
        ProfileEstimates.pillar3aLimit(selfEmployed, employeeLimit),
        const Money.cents(2000000),
      );
      expect(
        ProfileEstimates.pillar3aLimit(
          selfEmployed.copyWith(grossIncome: const Money.cents(25000000)),
          employeeLimit,
        ),
        const Money.cents(3628800),
      );
      expect(
        ProfileEstimates.pillar3aLimit(const UserProfile(), employeeLimit),
        employeeLimit,
      );
    });

    test('a first marginal tax rate comes from canton, income and status', () {
      expect(ProfileEstimates.marginalRate(const UserProfile()), isNull);
      expect(
        ProfileEstimates.marginalRate(
          const UserProfile(canton: Canton.zg, grossIncome: Money.cents(11000000)),
        ),
        closeTo(.23, .001),
      );
      expect(
        ProfileEstimates.marginalRate(
          const UserProfile(
            canton: Canton.ge,
            civilStatus: CivilStatus.married,
            grossIncome: Money.cents(11000000),
          ),
        ),
        closeTo(.28, .001),
      );
    });

    test('estimates follow the profile until the user enters their own', () {
      final container = createTestContainer(
        session: UserSession.demo().copyWith(
          profile: const UserProfile(
            birthYear: 1975,
            employment: Employment.selfEmployed,
            grossIncome: Money.cents(9000000),
          ),
        ),
      );
      expect(container.read(retirementProfileProvider).birthYear, 1975);
      expect(
        container.read(wealthTargetsProvider).pillar3aAnnualLimit,
        const Money.cents(1800000),
      );
    });
  });

  testWidgets('the about-you screen saves answers and the risk check', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final container = createTestContainer(session: const UserSession());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildFinoraTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AboutYouScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile 0% complete'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '1990');
    await tester.pump();
    await tester.tap(find.text('Self-employed'));
    await tester.pumpAndSettle();
    final profile = container.read(sessionProvider).profile;
    expect(profile.birthYear, 1990);
    expect(profile.employment, Employment.selfEmployed);

    await tester.scrollUntilVisible(
      find.text('Take the 3-question check'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take the 3-question check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In more than 10 years'));
    await tester.tap(find.text('Buy more while prices are low'));
    await tester.tap(find.text('I invest regularly'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile: Dynamic'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(container.read(sessionProvider).profile.risk, RiskProfile.dynamic);
    expect(tester.takeException(), isNull);
  });
}
