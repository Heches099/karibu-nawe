import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/period_selector.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_badge.dart';
import 'activity_feed.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateRange? _range;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = store.summary.dashboard(
      tasks: store.tasks,
      calculations: store.calculations,
      allocations: store.allocations,
      payments: store.payments,
      collections: store.collections,
      handovers: store.handovers,
      totalWorkers: store.workers.length,
      from: _range?.from,
      to: _range?.to,
    );
    final isWide = MediaQuery.of(context).size.width >= 1100;

    final grid = <Widget>[
      StatCard(
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF2E7D32),
        label: 'Active Tasks',
        value: Text('${stats.activeTasks}'),
        onTap: () {},
      ),
      StatCard(
        icon: Icons.groups_outlined,
        color: const Color(0xFF0277BD),
        label: 'Workers',
        value: Text('${stats.totalWorkers}'),
        sub: '${stats.workersWithAllocations} allocated in period',
      ),
      StatCard(
        icon: Icons.landscape_outlined,
        color: const Color(0xFF6A1B9A),
        label: 'Total Area',
        value: Text(formatArea(stats.totalArea)),
      ),
      StatCard(
        icon: Icons.functions_outlined,
        color: const Color(0xFF2E7D32),
        label: 'Expected',
        value: MoneyText(stats.expected),
        accent: true,
      ),
      StatCard(
        icon: Icons.handshake_outlined,
        color: const Color(0xFF6A1B9A),
        label: 'Allocated',
        value: MoneyText(stats.allocated),
        sub: stats.adjustmentTotal.abs() > 0.01
            ? 'Adjustments ${fmtSigned(stats.adjustmentTotal)}'
            : null,
      ),
      StatCard(
        icon: Icons.payments_outlined,
        color: const Color(0xFF2E7D32),
        label: 'Paid',
        value: MoneyText(stats.paid),
      ),
      StatCard(
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFFC62828),
        label: 'Remaining',
        value: MoneyText(stats.remaining),
      ),
      StatCard(
        icon: Icons.arrow_downward,
        color: const Color(0xFF0277BD),
        label: 'Collected For Others',
        value: MoneyText(stats.collectedForOthers),
        sub: '${stats.totalWorkers} workers · collector side',
      ),
      StatCard(
        icon: Icons.hourglass_empty,
        color: stats.pendingHandover > 0 ? const Color(0xFFEF6C00) : const Color(0xFF2E7D32),
        label: 'Pending Handover',
        value: MoneyText(stats.pendingHandover),
        sub: 'Handed over ${fmtMoney(stats.handedOver)}',
        accent: stats.pendingHandover > 0,
      ),
    ];

    final alerts = <Widget>[
      if (stats.adjustedAllocations > 0) _AlertTile(
        icon: Icons.swap_horiz,
        color: const Color(0xFF6A1B9A),
        text: '${stats.adjustedAllocations} worker allocation${stats.adjustedAllocations == 1 ? '' : 's'} differ${stats.adjustedAllocations == 1 ? 's' : ''} from expected',
      ),
      if (stats.pendingHandover > 0) _AlertTile(
        icon: Icons.hourglass_empty,
        color: const Color(0xFFEF6C00),
        text: '${fmtMoney(stats.pendingHandover)} pending handover for collectors',
      ),
      if (stats.partialPayments > 0) _AlertTile(
        icon: Icons.hourglass_top,
        color: const Color(0xFFF9A825),
        text: '${stats.partialPayments} partial payment${stats.partialPayments == 1 ? '' : 's'} outstanding',
      ),
      if (stats.unpaidAllocations > 0) _AlertTile(
        icon: Icons.error_outline,
        color: const Color(0xFFC62828),
        text: '${stats.unpaidAllocations} allocation${stats.unpaidAllocations == 1 ? '' : 's'} not yet paid',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Boss Dashboard',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                              Text(
                                _range == null ? 'Everything to date' : '${fmtDate(_range!.from)} to ${fmtDate(_range!.to)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(store.isConnected ? BadgeKind.live : BadgeKind.offline, pulse: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PeriodSelector(initial: ReportPeriod.today, onChanged: (r) => setState(() => _range = r)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 3 : (MediaQuery.of(context).size.width >= 600 ? 3 : 2),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.9 : 1.45,
                ),
                delegate: SliverChildListDelegate(grid),
              ),
            ),
            if (alerts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'ATTENTION REQUIRED', divider: false),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(children: alerts),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: const SectionHeader(title: 'RECENT ACTIVITY', divider: false),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ActivityFeed(limit: 12),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  String formatArea(double area) {
    final rounded = area.round();
    return '$rounded m²';
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _AlertTile({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}