import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/store/app_store.dart';
import '../audit/audit_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../tasks/tasks_screen.dart';
import '../workers/workers_screen.dart';
import '../../shared/widgets/status_badge.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isWide = MediaQuery.of(context).size.width >= 1100;

    final screens = [
      const DashboardScreen(),
      const TasksScreen(),
      const WorkersScreen(),
      const ReportsScreen(),
      const AuditScreen(),
      const SettingsScreen(),
    ];

    final navItems = [
      _NavDef(Icons.space_dashboard_outlined, Icons.space_dashboard, 'Dashboard'),
      _NavDef(Icons.fact_check_outlined, Icons.fact_check, 'Tasks'),
      _NavDef(Icons.groups_outlined, Icons.groups, 'Workers'),
      _NavDef(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
      _NavDef(Icons.history, Icons.history, 'Activity'),
      _NavDef(Icons.settings_outlined, Icons.settings, 'Settings'),
    ];

    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              minExtendedWidth: 220,
              extended: true,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
              leading: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.eco, color: StatusColors.live),
                    const SizedBox(width: 10),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16, right: 12),
                    child: StatusBadge(store.isConnected ? BadgeKind.live : BadgeKind.offline, pulse: true),
                  ),
                ),
              ),
              destinations: [
                for (final n in navItems)
                  NavigationRailDestination(icon: Icon(n.icon), selectedIcon: Icon(n.selectedIcon), label: Text(n.label)),
              ],
            ),
          Expanded(
            child: IndexedStack(index: _index, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final n in navItems) NavigationDestination(icon: Icon(n.icon), selectedIcon: Icon(n.selectedIcon), label: n.label),
              ],
            ),
    );
  }
}

class _NavDef {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavDef(this.icon, this.selectedIcon, this.label);
}