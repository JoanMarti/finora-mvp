import 'package:finora/features/accounts/accounts_screens.dart';
import 'package:finora/features/activity/activity_screen.dart';
import 'package:finora/features/connections/connection_screen.dart';
import 'package:finora/features/onboarding/onboarding_screen.dart';
import 'package:finora/features/overview/dashboard_screen.dart';
import 'package:finora/features/profile/profile_screen.dart';
import 'package:finora/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/onboarding'),
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
            const Text('We could not find that page.'),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go to overview'),
            ),
          ],
        ),
      ),
    ),
  );
});
