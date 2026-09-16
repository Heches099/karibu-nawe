import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/audit_log.dart';
import '../../state/app_state.dart';
import '../../shared/widgets/summary_card.dart';
import '../tasks/task_list_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../collections/collectors_screen.dart';
import '../audit/audit_screen.dart';

/// Boss Mode home screen (spec sections 19–21, 31). Answers "what is
/// happening right now" at a glance, live, without manual calculation.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final metrics = app.todayMetrics();
    final activity = app.auditRepo.recent(limit: 12);

    final warnings = <String>[
      if (metrics.adjustedAllocations > 0)
        '${metrics.adjustedAllocations} worker allocation${metrics.adjustedAllocations == 1 ? '' : 's'} differ from expected',
      if (metrics.pendingHandover > 0)
        '${CurrencyFormatter.format(metrics.pendingHandover)} pending handover',
      if (metrics.partialPayments > 0)
        '${metrics.partialPayments} partial payment${metrics.partialPayments == 1 ? '' : 's'}',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Operations'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _LiveIndicator(isOnline: app.isOnline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const TaskListScreen(openCreate: true))),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Today · ${DateFormatter.date(DateTime.now())}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _MetricsGrid(metrics: metrics),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 20),
              _WarningsCard(warnings: warnings),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick Links', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickLink(
                  icon: Icons.list_alt,
                  label: 'All Tasks',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TaskListScreen())),
                ),
                _QuickLink(
                  icon: Icons.groups_2_outlined,
                  label: 'Collectors',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CollectorsScreen())),
                ),
                _QuickLink(
                  icon: Icons.history,
                  label: 'Full Audit Trail',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const AuditScreen())),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (activity.isEmpty)
              const _EmptyActivity()
            else
              ...activity.map((log) => _ActivityTile(log: log)),
          ],
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final DashboardMetrics metrics;
  const _MetricsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width > 900 ? 4 : (width > 600 ? 3 : 2);

    final tiles = [
      SummaryCard(
          label: 'Active Tasks',
          value: '${metrics.activeTasks}',
          icon: Icons.task_alt,
          color: AppTheme.info),
      SummaryCard(
          label: 'Workers',
          value: '${metrics.workerCount}',
          icon: Icons.people_outline,
          color: AppTheme.neutral),
      SummaryCard(
          label: 'Total Area',
          value: '${metrics.totalArea.toStringAsFixed(0)} m²',
          icon: Icons.crop_square,
          color: AppTheme.info),
      SummaryCard(
          label: 'Expected',
          value: CurrencyFormatter.format(metrics.expected),
          icon: Icons.calculate_outlined,
          color: AppTheme.neutral),
      SummaryCard(
          label: 'Allocated',
          value: CurrencyFormatter.format(metrics.allocated),
          icon: Icons.assignment_ind_outlined,
          color: AppTheme.info),
      SummaryCard(
          label: 'Paid',
          value: CurrencyFormatter.format(metrics.paid),
          icon: Icons.payments_outlined,
          color: AppTheme.success),
      SummaryCard(
          label: 'Remaining',
          value: CurrencyFormatter.format(metrics.remaining),
          icon: Icons.pending_actions,
          color: metrics.remaining > 0 ? AppTheme.warning : AppTheme.success),
      SummaryCard(
          label: 'Collected For Others',
          value: CurrencyFormatter.format(metrics.collectedForOthers),
          icon: Icons.compare_arrows,
          color: AppTheme.info),
      SummaryCard(
          label: 'Pending Handover',
          value: CurrencyFormatter.format(metrics.pendingHandover),
          icon: Icons.hourglass_bottom,
          color: metrics.pendingHandover > 0 ? AppTheme.warning : AppTheme.success),
    ];

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: tiles,
    );
  }
}

class _WarningsCard extends StatelessWidget {
  final List<String> warnings;
  const _WarningsCard({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
              SizedBox(width: 8),
              Text('Needs Attention', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ...warnings.map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('⚠ $w'),
                )),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  final bool isOnline;
  const _LiveIndicator({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppTheme.success : AppTheme.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(isOnline ? 'LIVE' : 'OFFLINE — syncing when connected',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      ]),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(children: [
              Icon(Icons.inbox_outlined, color: Colors.grey[400], size: 36),
              const SizedBox(height: 8),
              Text('No activity yet', style: TextStyle(color: Colors.grey[600])),
            ]),
          ),
        ),
      );
}

class _ActivityTile extends StatelessWidget {
  final AuditLog log;
  const _ActivityTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: log.taskId == null
            ? null
            : () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: log.taskId!))),
        leading: CircleAvatar(
          backgroundColor: AppTheme.seed.withValues(alpha: 0.12),
          child: const Icon(Icons.circle, size: 10, color: AppTheme.seed),
        ),
        title: Text(log.description),
        subtitle: Text([
          if (log.workerId != null) app.workerName(log.workerId!),
          DateFormatter.relative(log.timestamp),
        ].join(' · ')),
      ),
    );
  }
}
