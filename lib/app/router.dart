import 'package:finora/application/session_controller.dart';
import 'package:finora/features/accounts/account_detail_screen.dart';
import 'package:finora/features/accounts/accounts_screen.dart';
import 'package:finora/features/accounts/institution_detail_screen.dart';
import 'package:finora/features/activity/activity_screen.dart';
import 'package:finora/features/analysis/analysis_screen.dart';
import 'package:finora/features/assets/assets_screen.dart';
import 'package:finora/features/budgets/budgets_screen.dart';
import 'package:finora/features/budgets/subscriptions_screen.dart';
import 'package:finora/features/calendar/calendar_screen.dart';
import 'package:finora/features/connections/connection_screen.dart';
import 'package:finora/features/debts/debts_screen.dart';
import 'package:finora/features/health/health_screen.dart';
import 'package:finora/features/household/household_screen.dart';
import 'package:finora/features/onboarding/onboarding_screen.dart';
import 'package:finora/features/offers/opportunities_screen.dart';
import 'package:finora/features/offers/pilot_metrics_screen.dart';
import 'package:finora/features/overview/dashboard_screen.dart';
import 'package:finora/features/planning/goals_screen.dart';
import 'package:finora/features/planning/retirement_screen.dart';
import 'package:finora/features/planning/tax_summary_screen.dart';
import 'package:finora/features/plus/plus_screen.dart';
import 'package:finora/features/privacy/privacy_screen.dart';
import 'package:finora/features/profile/profile_screen.dart';
import 'package:finora/features/simulators/home_buying_screen.dart';
import 'package:finora/features/simulators/tax_savings_screen.dart';
import 'package:finora/features/shell/app_shell.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Routes reachable before onboarding is finished.
const _onboardingRoutes = {'/onboarding', '/connect'};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects when onboarding completes or the session resets,
  // without rebuilding the router (which would lose navigation state).
  final onboardingCompleted = ValueNotifier<bool>(
    ref.read(sessionProvider).onboardingCompleted,
  );
  ref
    ..listen(
      sessionProvider.select((session) => session.onboardingCompleted),
      (_, next) => onboardingCompleted.value = next,
    )
    ..onDispose(onboardingCompleted.dispose);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: onboardingCompleted,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (!onboardingCompleted.value) {
        return _onboardingRoutes.contains(location) ? null : '/onboarding';
      }
      if (location == '/onboarding' || location == '/') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/connect', builder: (_, _) => const ConnectionScreen()),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/accounts', builder: (_, _) => const AccountsScreen()),
          GoRoute(path: '/activity', builder: (_, _) => const ActivityScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/goals', builder: (_, _) => const GoalsScreen()),
      GoRoute(
        path: '/retirement',
        builder: (_, _) => const RetirementScreen(),
      ),
      GoRoute(path: '/tax', builder: (_, _) => const TaxSummaryScreen()),
      GoRoute(path: '/analysis', builder: (_, _) => const AnalysisScreen()),
      GoRoute(
        path: '/offers',
        builder: (_, _) => const OpportunitiesScreen(),
      ),
      GoRoute(path: '/health', builder: (_, _) => const HealthScreen()),
      GoRoute(path: '/budgets', builder: (_, _) => const BudgetsScreen()),
      GoRoute(path: '/debts', builder: (_, _) => const DebtsScreen()),
      GoRoute(
        path: '/subscriptions',
        builder: (_, _) => const SubscriptionsScreen(),
      ),
      GoRoute(path: '/home-buying', builder: (_, _) => const HomeBuyingScreen()),
      GoRoute(
        path: '/tax-savings',
        builder: (_, _) => const TaxSavingsScreen(),
      ),
      GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
      GoRoute(
        path: '/household',
        builder: (_, _) => const HouseholdScreen(),
      ),
      GoRoute(path: '/assets', builder: (_, _) => const AssetsScreen()),
      GoRoute(path: '/plus', builder: (_, _) => const PlusScreen()),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
      GoRoute(
        path: '/pilot-metrics',
        builder: (_, _) => const PilotMetricsScreen(),
      ),
      GoRoute(
        path: '/institution/:institutionId',
        builder: (_, state) => InstitutionDetailScreen(
          institutionId: state.pathParameters['institutionId']!,
        ),
      ),
      GoRoute(
        path: '/account/:accountId',
        builder: (_, state) =>
            AccountDetailScreen(accountId: state.pathParameters['accountId']!),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(context.l10n.pageNotFound),
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text(context.l10n.goToOverview),
            ),
          ],
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
