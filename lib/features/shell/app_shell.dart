import 'package:finora/app/layout.dart';
import 'package:finora/app/theme.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One place in the app's navigation.
class NavItem {
  const NavItem(this.route, this.icon, this.selectedIcon, this.label);
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l10n) label;
}

/// A titled group of [NavItem]s in the desktop sidebar.
class NavGroup {
  const NavGroup(this.title, this.items);
  final String Function(AppLocalizations l10n) title;
  final List<NavItem> items;
}

final _wealth = NavItem(
  '/home',
  Icons.pie_chart_outline_rounded,
  Icons.pie_chart_rounded,
  (l10n) => l10n.navWealth,
);
final _accounts = NavItem(
  '/accounts',
  Icons.account_balance_outlined,
  Icons.account_balance,
  (l10n) => l10n.navAccounts,
);
final _activity = NavItem(
  '/activity',
  Icons.receipt_long_outlined,
  Icons.receipt_long,
  (l10n) => l10n.navActivity,
);
final _profile = NavItem(
  '/profile',
  Icons.person_outline,
  Icons.person,
  (l10n) => l10n.navProfile,
);
final _analysis = NavItem(
  '/analysis',
  Icons.donut_small_outlined,
  Icons.donut_small,
  (l10n) => l10n.navAnalysis,
);
final _goals = NavItem(
  '/goals',
  Icons.flag_outlined,
  Icons.flag,
  (l10n) => l10n.navGoals,
);
final _offers = NavItem(
  '/offers',
  Icons.savings_outlined,
  Icons.savings,
  (l10n) => l10n.navOffers,
);

/// The four places on the phone's bottom bar.
final primaryNavItems = [_wealth, _accounts, _activity, _profile];

/// The rail on tablets: primary places plus the most used tools.
final railNavItems = [
  _wealth,
  _accounts,
  _activity,
  _analysis,
  _goals,
  _offers,
  _profile,
];

/// Every section, grouped, for the desktop sidebar.
final sidebarNavGroups = [
  NavGroup((l10n) => l10n.navGroupOverview, [
    _wealth,
    _accounts,
    _activity,
    _analysis,
    NavItem(
      '/report',
      Icons.insert_chart_outlined,
      Icons.insert_chart,
      (l10n) => l10n.navReport,
    ),
    NavItem(
      '/annual-report',
      Icons.picture_as_pdf_outlined,
      Icons.picture_as_pdf,
      (l10n) => l10n.annualReportTitle,
    ),
  ]),
  NavGroup((l10n) => l10n.navGroupPlan, [
    NavItem(
      '/budgets',
      Icons.pie_chart_outline,
      Icons.pie_chart,
      (l10n) => l10n.budgetsTitle,
    ),
    _goals,
    NavItem(
      '/calendar',
      Icons.calendar_month_outlined,
      Icons.calendar_month,
      (l10n) => l10n.navCalendar,
    ),
    NavItem(
      '/retirement',
      Icons.beach_access_outlined,
      Icons.beach_access,
      (l10n) => l10n.navRetirement,
    ),
    NavItem(
      '/home-buying',
      Icons.house_outlined,
      Icons.house,
      (l10n) => l10n.navHomeBuying,
    ),
    NavItem(
      '/tax',
      Icons.description_outlined,
      Icons.description,
      (l10n) => l10n.navTax,
    ),
    NavItem(
      '/tax-documents',
      Icons.fact_check_outlined,
      Icons.fact_check,
      (l10n) => l10n.taxDocsTitle,
    ),
  ]),
  NavGroup((l10n) => l10n.navGroupSave, [
    _offers,
    NavItem(
      '/price-alerts',
      Icons.trending_up,
      Icons.trending_up,
      (l10n) => l10n.priceAlertsTitle,
    ),
    NavItem(
      '/subscriptions',
      Icons.autorenew,
      Icons.autorenew,
      (l10n) => l10n.subscriptionsTitle,
    ),
    NavItem(
      '/health-insurance',
      Icons.health_and_safety_outlined,
      Icons.health_and_safety,
      (l10n) => l10n.healthInsTitle,
    ),
    NavItem(
      '/tax-savings',
      Icons.calculate_outlined,
      Icons.calculate,
      (l10n) => l10n.navTaxSavings,
    ),
    NavItem(
      '/debts',
      Icons.trending_down,
      Icons.trending_down,
      (l10n) => l10n.navDebts,
    ),
  ]),
  NavGroup((l10n) => l10n.navGroupYou, [
    NavItem(
      '/about-you',
      Icons.badge_outlined,
      Icons.badge,
      (l10n) => l10n.aboutYouTitle,
    ),
    NavItem(
      '/health',
      Icons.favorite_border,
      Icons.favorite,
      (l10n) => l10n.navHealth,
    ),
    NavItem(
      '/household',
      Icons.family_restroom,
      Icons.family_restroom,
      (l10n) => l10n.householdTitle,
    ),
    NavItem(
      '/assets',
      Icons.home_work_outlined,
      Icons.home_work,
      (l10n) => l10n.navAssets,
    ),
    _profile,
  ]),
];

/// The navigation section a location belongs to. Account and institution
/// pages belong to the accounts section.
String navSectionOf(String path) {
  if (path.startsWith('/account/') || path.startsWith('/institution/')) {
    return '/accounts';
  }
  final second = path.indexOf('/', 1);
  return second == -1 ? path : path.substring(0, second);
}

/// Frame around every signed-in page: a bottom bar on phones, a rail on
/// tablets and a full sidebar on desktop.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        // The top route, including pages opened with push.
        final path = router.state.uri.path;
        final section = navSectionOf(path);
        return switch (FinoraWindow.of(context)) {
          FinoraWindow.compact => _CompactShell(
            path: path,
            child: child,
          ),
          FinoraWindow.medium => _RailShell(section: section, child: child),
          FinoraWindow.expanded => _SidebarShell(
            section: section,
            child: child,
          ),
        };
      },
    );
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({required this.path, required this.child});

  /// Full location: only the main pages themselves show the bar.
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = primaryNavItems.indexWhere((item) => item.route == path);
    final l10n = context.l10n;
    return Scaffold(
      body: child,
      // Secondary pages stay full screen on phones.
      bottomNavigationBar: index == -1
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: finoraBorder)),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (next) =>
                    context.go(primaryNavItems[next].route),
                destinations: [
                  for (final item in primaryNavItems)
                    NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label(l10n),
                    ),
                ],
              ),
            ),
    );
  }
}

class _RailShell extends StatelessWidget {
  const _RailShell({required this.section, required this.child});
  final String section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = railNavItems.indexWhere((item) => item.route == section);
    final l10n = context.l10n;
    return Scaffold(
      body: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: finoraWhite,
              border: Border(right: BorderSide(color: finoraBorder)),
            ),
            child: NavigationRail(
              backgroundColor: finoraWhite,
              selectedIndex: index == -1 ? null : index,
              labelType: NavigationRailLabelType.all,
              indicatorColor: finoraSoftBlue,
              selectedIconTheme: const IconThemeData(color: finoraBlueText),
              leading: const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 12),
                child: _BrandMark(),
              ),
              onDestinationSelected: (next) =>
                  context.go(railNavItems[next].route),
              destinations: [
                for (final item in railNavItems)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label(l10n)),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SidebarShell extends StatelessWidget {
  const _SidebarShell({required this.section, required this.child});
  final String section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 256,
            decoration: const BoxDecoration(
              color: finoraWhite,
              border: Border(right: BorderSide(color: finoraBorder)),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        const _BrandMark(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Finora',
                                style: TextStyle(
                                  color: finoraInk,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.3,
                                ),
                              ),
                              Text(
                                l10n.sidebarTagline,
                                maxLines: 2,
                                style: const TextStyle(
                                  color: finoraMutedInk,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      children: [
                        for (final group in sidebarNavGroups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                            child: Text(
                              group.title(l10n).toUpperCase(),
                              style: const TextStyle(
                                color: finoraSlate,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .8,
                              ),
                            ),
                          ),
                          for (final item in group.items)
                            _SidebarTile(
                              item: item,
                              selected: item.route == section,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.selected});
  final NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final label = item.label(context.l10n);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? finoraSoftBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(finoraRadiusControl),
          child: InkWell(
            borderRadius: BorderRadius.circular(finoraRadiusControl),
            onTap: () => context.go(item.route),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 20,
                    color: selected ? finoraBlueText : finoraMutedInk,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? finoraInk : finoraMutedInk,
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small gradient square with the Finora initial.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: finoraBrandGradient,
      borderRadius: BorderRadius.circular(finoraRadiusControl),
    ),
    child: const Text(
      'F',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
