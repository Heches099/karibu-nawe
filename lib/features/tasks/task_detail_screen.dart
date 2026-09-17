import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../services/store/app_store.dart';
import '../../services/summary/summary_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/forms.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/status_badge.dart';
import '../allocations/allocation_sheets.dart';
import '../calculator/calculator_screen.dart';
import '../collections/collection_sheet.dart';
import '../collections/collector_summary_screen.dart';
import '../dashboard/activity_feed.dart';
import '../area_measurement/area_measurement_screen.dart';
import '../payments/payment_sheet.dart';
import '../workers/worker_detail_screen.dart';

class TaskDetailScreen extends StatelessWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final task = store.taskById(taskId);
    if (task == null) {
      return const Scaffold(body: Center(child: Text('Task not found.')));
    }
    return DefaultTabController(
      length: 6,
      child: _DetailBody(task: task),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Task task;
  const _DetailBody({required this.task});

  Future<void> _changeStatus(BuildContext context, TaskStatus status) async {
    final store = context.read<AppStore>();
    try {
      store.updateTaskStatus(task.id, status);
      if (context.mounted) showSuccess(context, 'Task marked ${status.label}.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wt = store.workTypeById(task.workTypeId);
    final calc = store.calculationFor(task.id);
    final summary = store.summary.summarizeTask(
      taskId: task.id,
      calculations: store.calculations,
      allocations: store.allocations,
      payments: store.payments,
      collections: store.collections,
      handovers: store.handovers,
    );
    final badge = switch (task.status) {
      TaskStatus.active => BadgeKind.active,
      TaskStatus.completed => BadgeKind.completed,
      TaskStatus.cancelled => BadgeKind.cancelled,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Calculator'),
            Tab(text: 'Workers'),
            Tab(text: 'Payments'),
            Tab(text: 'Collections'),
            Tab(text: 'Activity'),
          ],
        ),
        actions: [
          PopupMenuButton<TaskStatus>(
            icon: const Icon(Icons.more_vert),
            onSelected: (s) => _changeStatus(context, s),
            itemBuilder: (_) => [
              for (final s in TaskStatus.values)
                PopupMenuItem(value: s, child: Text(s.label)),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              _TaskHeader(task: task, calc: calc, summary: summary, wtName: wt?.name ?? '—', badge: badge),
              Expanded(
                child: TabBarView(
                  children: [
                    _OverviewTab(task: task, calc: calc, summary: summary),
                    CalculatorScreen(task: task, key: ValueKey('calc_${task.id}_${calc?.id ?? 0}')),
                    _WorkersTab(task: task),
                    _PaymentsTab(task: task),
                    _CollectionsTab(task: task),
                    _ActivityTab(task: task),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskHeader extends StatelessWidget {
  final Task task;
  final Calculation? calc;
  final TaskSummary summary;
  final String wtName;
  final BadgeKind badge;
  const _TaskHeader({required this.task, required this.calc, required this.summary, required this.wtName, required this.badge});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final calcData = calc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(task.description.isEmpty ? '—' : task.description, style: Theme.of(context).textTheme.bodyMedium)),
              StatusBadge(badge),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _chip(context, Icons.category_outlined, wtName),
              _chip(context, Icons.place_outlined, task.field),
              _chip(context, Icons.event, fmtDate(task.workDate)),
              _chip(context, Icons.person_outline, 'Created by ${task.createdBy}'),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  _mini(context, scheme, 'Area', calcData == null ? '—' : fmtArea((calcData.outputs['area'] as num?)?.toDouble() ?? 0)),
                  _miniSep(scheme),
                  _miniMoney(context, scheme, 'Expected', summary.expected),
                  _miniSep(scheme),
                  _miniMoney(context, scheme, 'Allocated', summary.allocated),
                  _miniSep(scheme),
                  _miniMoney(context, scheme, 'Paid', summary.paid),
                  _miniSep(scheme),
                  _miniMoney(context, scheme, 'Remaining', summary.remaining),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      );

  Widget _mini(BuildContext context, ColorScheme scheme, String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _miniMoney(BuildContext context, ColorScheme scheme, String label, double value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.4)),
            const SizedBox(height: 2),
            MoneyText(value, compact: true, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );

  Widget _miniSep(ColorScheme scheme) => Container(width: 1, height: 30, color: scheme.outlineVariant.withValues(alpha: 0.5));
}

class _OverviewTab extends StatelessWidget {
  final Task task;
  final Calculation? calc;
  final TaskSummary summary;
  const _OverviewTab({required this.task, required this.calc, required this.summary});

  void _open(BuildContext outer, Widget sheet, String title) {
    showAppSheet(outer, sheet, title: title);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final calcData = calc;
    final measurements = store.measurementsForTask(task.id);
    final latestMeasurement = measurements.isEmpty ? null : measurements.first;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: 'QUICK ACTIONS'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.person_add_alt), label: const Text('Assign Worker'),
              onPressed: () => _open(context, AssignWorkerSheet(task: task), 'Assign Worker'),
            ),
            ActionChip(
              avatar: const Icon(Icons.payments_outlined), label: const Text('Record Payment'),
              onPressed: () => _open(context, PaymentSheet(task: task), 'Record Payment'),
            ),
            ActionChip(
              avatar: const Icon(Icons.calculate_outlined), label: Text(calc == null ? 'Run Calculator' : 'Calculator Saved'),
              onPressed: calc == null
                  ? () => _open(context, CalculatorScreen(task: task), 'Calculator')
                  : null,
            ),
            ActionChip(
              avatar: const Icon(Icons.gps_fixed),
              label: Text(latestMeasurement == null ? 'Measure Area' : 'Measure Area Again'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AreaMeasurementScreen(task: task))),
            ),
            if (summary.collectedForOthers > 0)
              ActionChip(
                avatar: const Icon(Icons.arrow_downward), label: const Text('Collection'),
                onPressed: () => _open(context, CollectionSheet(task: task), 'Record Collection'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'TASK'),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              _kv(context, 'Title', task.title),
              _kv(context, 'Description', task.description.isEmpty ? '—' : task.description),
              _kv(context, 'Work Date', fmtDate(task.workDate)),
              _kv(context, 'Farm / Field', task.field),
              _kv(context, 'Status', task.status.label),
              if (latestMeasurement != null)
                _kv(context, 'Saved survey area', '${fmtArea(latestMeasurement.areaM2)} · ${latestMeasurement.syncStatus.name}'),
              if (task.notes != null && task.notes!.isNotEmpty) _kv(context, 'Notes', task.notes!),
              _kv(context, 'Created', '${fmtDateTime(task.createdAt)} by ${task.createdBy}'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'EXPECTED SUMMARY'),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              _kv(context, 'Measured Area', calcData == null ? '—' : fmtArea((calcData.outputs['area'] as num?)?.toDouble() ?? 0)),
              MoneyRow(label: 'Expected (baseline)', value: summary.expected),
              MoneyRow(label: 'Allocated', value: summary.allocated),
              if (summary.adjustmentTotal.abs() > 0.01) ...[
                const Divider(),
                MoneyRow(label: 'Adjustments', value: summary.adjustmentTotal),
              ],
              const Divider(),
              MoneyRow(label: 'Paid', value: summary.paid),
              MoneyRow(label: 'Remaining', value: summary.remaining),
              const Divider(),
              MoneyRow(label: 'Collected for others', value: summary.collectedForOthers),
              MoneyRow(label: 'Pending handover', value: summary.pendingHandover),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _WorkersTab extends StatelessWidget {
  final Task task;
  const _WorkersTab({required this.task});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final allocs = store.allocationsFor(task.id);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title: 'WORKERS (${allocs.length})', divider: false)),
            FilledButton.tonalIcon(
              onPressed: () => showAppSheet(context, AssignWorkerSheet(task: task), title: 'Assign Worker'),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Assign'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (allocs.isEmpty)
          const EmptyState(
            icon: Icons.groups_outlined,
            title: 'No workers assigned yet',
            message: 'Assign workers to this task using the button above.',
          )
        else if (isWide)
          _WorkersTable(task: task)
        else
          ...[
            for (final a in allocs) ...[
              _WorkerTile(allocation: a),
              const SizedBox(height: 10),
            ],
            _WorkersTotals(task: task),
          ],
      ],
    );
  }
}

class _WorkersTotals extends StatelessWidget {
  final Task task;
  const _WorkersTotals({required this.task});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final summary = store.summary.summarizeTask(
      taskId: task.id,
      calculations: store.calculations,
      allocations: store.allocations,
      payments: store.payments,
      collections: store.collections,
      handovers: store.handovers,
    );
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('TOTAL SUMMARY', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _totalValue('Expected', summary.expected),
                _totalValue('Allocated', summary.allocated),
                _totalValue('Paid', summary.paid),
                _totalValue('Remaining', summary.remaining),
                _totalValue('Collected for others', summary.collectedForOthers),
                _totalValue('Pending handover', summary.pendingHandover),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalValue(String label, double value) => SizedBox(
        width: 145,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            MoneyText(value, compact: true, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _WorkerTile extends StatelessWidget {
  final Allocation allocation;
  const _WorkerTile({required this.allocation});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final worker = store.workerById(allocation.workerId);
    final task = store.taskById(allocation.taskId);
    final paid = store.totalPaidFor(taskId: allocation.taskId, workerId: allocation.workerId);
    final remaining = allocation.allocatedAmount - paid;
    final status = store.paymentStatusFor(taskId: allocation.taskId, workerId: allocation.workerId, allocated: allocation.allocatedAmount);
    final diff = allocation.allocatedAmount - allocation.expectedAmount;
    final adjustCount = store.adjustmentsFor(allocation.id).length;
    final collections = store.collectionsForWorker(allocation.workerId, taskId: allocation.taskId);
    final collectorName = collections.isNotEmpty ? store.workerName(collections.first.collectorId) : null;

    return Card(
      child: InkWell(
        onTap: () {
          final w = worker;
          if (w == null) return;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WorkerDetailScreen(workerId: w.id),
          ));
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(worker?.name ?? '—', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  _PaymentBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _statBox(context, 'Expected', fmtMoney(allocation.expectedAmount.round()))),
                  Expanded(child: _statBox(context, 'Allocated', fmtMoney(allocation.allocatedAmount.round()))),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (diff).abs() > 0.001 ? const Color(0xFF6A1B9A).withValues(alpha: 0.08) : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adj.', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          MoneyText(diff, showSign: true, compact: true),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: _statBox(context, 'Paid', fmtMoney(paid.round()))),
                  Expanded(child: _statBox(context, 'Remaining', fmtMoney(remaining.round()))),
                ],
              ),
              if ((diff).abs() > 0.001)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Adjusted from TSh ${fmtMoneyPlain(allocation.expectedAmount.round())}',
                    style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              if (collectorName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_downward, size: 14, color: Color(0xFF0277BD)),
                      const SizedBox(width: 4),
                      Text('Collected by $collectorName',
                          style: const TextStyle(color: Color(0xFF0277BD), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), visualDensity: VisualDensity.compact),
                    onPressed: () => showAppSheet(context, AdjustAllocationSheet(allocation: allocation), title: 'Adjust Allocation'),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Adjust'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), visualDensity: VisualDensity.compact),
                    onPressed: () {
                      final w = worker;
                      final t = task;
                      if (w != null && t != null) showAppSheet(context, PaymentSheet(task: t, worker: w), title: 'Record Payment');
                    },
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Pay'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), visualDensity: VisualDensity.compact),
                    onPressed: () => showAppSheet(context, AllocationHistorySheet(allocation: allocation), title: 'Activity / History'),
                    icon: const Icon(Icons.history, size: 16),
                    label: Text('History${adjustCount > 0 ? ' ($adjustCount)' : ''}'),
                  ),
                  if (status != PaymentStatus.paid)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), visualDensity: VisualDensity.compact),
                      onPressed: () async {
                        try {
                          final payment = await store.payAllocation(task: task!, worker: worker!);
                          if (context.mounted) showSuccess(context, '${worker.name} paid TSh ${payment.amount.round()}.');
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      },
                      icon: const Icon(Icons.payments_outlined, size: 16),
                      label: const Text('Pay'),
                    )
                  else
                    const Chip(avatar: Icon(Icons.check, size: 16), label: Text('Paid')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );
}

class _WorkersTable extends StatelessWidget {
  final Task task;
  const _WorkersTable({required this.task});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final allocs = store.allocationsFor(task.id);
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1100),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('S/N')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Job Type')),
              DataColumn(label: Text('Measurement')),
              DataColumn(label: Text('Expected'), numeric: true),
              DataColumn(label: Text('Allocated'), numeric: true),
              DataColumn(label: Text('Adjustment'), numeric: true),
              DataColumn(label: Text('Reason')),
              DataColumn(label: Text('Paid'), numeric: true),
              DataColumn(label: Text('Remaining'), numeric: true),
              DataColumn(label: Text('Payment Status')),
              DataColumn(label: Text('Payment')),
              DataColumn(label: Text('Collected By')),
              DataColumn(label: Text('Handover')),
            ],
            rows: [
              for (var i = 0; i < allocs.length; i++)
                _row(context, store, allocs[i], i + 1),
              _totalsRow(context, store, allocs),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, AppStore store, Allocation a, int sn) {
    final worker = store.workerById(a.workerId);
    final calc = store.calculationFor(task.id);
    final paid = store.totalPaidFor(taskId: a.taskId, workerId: a.workerId);
    final remaining = a.allocatedAmount - paid;
    final status = store.paymentStatusFor(taskId: a.taskId, workerId: a.workerId, allocated: a.allocatedAmount);
    final diff = a.allocatedAmount - a.expectedAmount;
    final adj = store.adjustmentsFor(a.id).firstOrNull;
    final collections = store.collectionsForWorker(a.workerId, taskId: a.taskId);
    var handed = 0.0;
    for (final h in store.handovers) {
      if (h.workerId == a.workerId && h.taskId == a.taskId) handed += h.amount;
    }
    final collectedAmount = collections.fold<double>(0, (s, c) => s + c.amount);

    return DataRow(
      onSelectChanged: (_) {
        final w = worker;
        if (w == null) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerDetailScreen(workerId: w.id)));
      },
      cells: [
        DataCell(Text('$sn')),
        DataCell(Text(worker?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w700))),
        DataCell(Text(store.workTypeOf(store.taskById(a.taskId)!)?.name ?? '—')),
        DataCell(Text(calc == null ? '—' : fmtArea((calc.outputs['area'] as num?)?.toDouble() ?? 0))),
        DataCell(MoneyText(a.expectedAmount, compact: true)),
        DataCell(MoneyText(a.allocatedAmount, compact: true)),
        DataCell(diff.abs() > 0.001 ? MoneyText(diff, showSign: true, compact: true, bold: false) : const Text('—', style: TextStyle(color: Color(0xFF9E9E9E)))),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(adj?.reason ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        )),
        DataCell(MoneyText(paid, compact: true)),
        DataCell(MoneyText(remaining, compact: true)),
        DataCell(StatusBadge(switch (status) {
          PaymentStatus.paid => BadgeKind.paid,
          PaymentStatus.partial => BadgeKind.partial,
          PaymentStatus.unpaid => BadgeKind.unpaid,
        })),
        DataCell(
          status == PaymentStatus.paid
              ? const Chip(avatar: Icon(Icons.check, size: 16), label: Text('PAID'))
              : FilledButton(
                  onPressed: worker == null
                      ? null
                      : () async {
                          try {
                            final payment = await store.payAllocation(task: task, worker: worker);
                            if (context.mounted) showSuccess(context, '${worker.name} paid TSh ${payment.amount.round()}.');
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                  child: const Text('PAY'),
                ),
        ),
        DataCell(collections.isEmpty
            ? const Text('—')
            : StatusBadge(
                BadgeKind.collectedByOther,
                label: 'Blue: ${store.workerName(collections.first.collectorId)}',
              )),
        DataCell(collections.isEmpty
            ? const Text('—')
            : handIsComplete(handed, collectedAmount)
                ? const StatusBadge(BadgeKind.completed, label: 'Handover complete')
                : const StatusBadge(BadgeKind.handoverPending, label: 'Yellow: pending')),
      ],
    );
  }

  DataRow _totalsRow(BuildContext context, AppStore store, List<Allocation> allocs) {
    final summary = store.summary.summarizeTask(
      taskId: task.id,
      calculations: store.calculations,
      allocations: store.allocations,
      payments: store.payments,
      collections: store.collections,
      handovers: store.handovers,
    );
    final totalHanded = store.handovers
        .where((h) => h.taskId == task.id)
        .fold<double>(0, (total, h) => total + h.amount);
    return DataRow(
      color: WidgetStatePropertyAll(Theme.of(context).colorScheme.primaryContainer),
      cells: [
        const DataCell(Text('')),
        const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900))),
        DataCell(Text('${allocs.length} workers', style: const TextStyle(fontWeight: FontWeight.w700))),
        const DataCell(Text('')),
        DataCell(MoneyText(summary.expected, compact: true, bold: true)),
        DataCell(MoneyText(summary.allocated, compact: true, bold: true)),
        DataCell(MoneyText(summary.adjustmentTotal, showSign: true, compact: true, bold: true)),
        const DataCell(Text('Summary', style: TextStyle(fontWeight: FontWeight.w700))),
        DataCell(MoneyText(summary.paid, compact: true, bold: true)),
        DataCell(MoneyText(summary.remaining, compact: true, bold: true)),
        DataCell(StatusBadge(summary.remaining <= 0.001 ? BadgeKind.paid : BadgeKind.pending, label: summary.remaining <= 0.001 ? 'Settled' : 'Open')),
        const DataCell(Text('')),
        DataCell(MoneyText(summary.collectedForOthers, compact: true, bold: true)),
        DataCell(MoneyText(summary.collectedForOthers - totalHanded, compact: true, bold: true)),
      ],
    );
  }

  bool handIsComplete(double handed, double collected) => collected <= 0 || handed >= collected - 0.001;
}

class _PaymentsTab extends StatelessWidget {
  final Task task;
  const _PaymentsTab({required this.task});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final pays = store.paymentsFor(taskId: task.id);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title: 'PAYMENT TRANSACTIONS (${pays.length})', divider: false)),
            FilledButton.tonalIcon(
              onPressed: () => showAppSheet(context, PaymentSheet(task: task), title: 'Record Payment'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Add Payment'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pays.isEmpty)
          const EmptyState(
            icon: Icons.payments_outlined,
            title: 'No payments yet',
            message: 'Payments and their collection relations are recorded here.',
          )
        else
          for (final p in pays)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                  child: Text('T${p.amount.round()}'.length > 6 ? 'T…' : 'TSh', style: const TextStyle(fontSize: 11)),
                ),
                title: Text('${store.workerName(p.workerId)} — TSh ${fmtMoneyPlain(p.amount.round())}'),
                subtitle: Text('${fmtDateTime(p.paidAt)} · ${p.method.isEmpty ? 'Cash' : p.method}${p.note ?? ''}'),
                trailing: Text('by ${p.recordedBy}', style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
      ],
    );
  }
}

class _CollectionsTab extends StatelessWidget {
  final Task task;
  const _CollectionsTab({required this.task});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cols = store.collections.where((c) => c.taskId == task.id).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title: 'COLLECTIONS (${cols.length})', divider: false)),
            FilledButton.tonalIcon(
              onPressed: () => showAppSheet(context, CollectionSheet(task: task), title: 'Record Collection'),
              icon: const Icon(Icons.arrow_downward),
              label: const Text('Collection'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (cols.isEmpty)
          const EmptyState(
            icon: Icons.arrow_downward,
            title: 'No collections',
            message: 'When a worker collects money for someone else it appears here, linked to both people.',
          )
        else
          for (final c in cols) ...[
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0277BD),
                  child: Icon(Icons.arrow_downward, color: Colors.white),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text('${store.workerName(c.collectorId)} collected for ${store.workerName(c.workerId)}')),
                    const StatusBadge(BadgeKind.collectedByOther, label: 'Blue'),
                  ],
                ),
                subtitle: Text(fmtDateTime(c.collectedAt)),
                trailing: MoneyText(c.amount),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CollectorSummaryScreen(collectorId: c.collectorId, taskId: task.id),
                  ));
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  final Task task;
  const _ActivityTab({required this.task});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: 'ACTIVITY / HISTORY'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ActivityFeed(taskId: task.id),
          ),
        ),
      ],
    );
  }
}

Widget _PaymentBadge(PaymentStatus status) => StatusBadge(switch (status) {
      PaymentStatus.paid => BadgeKind.paid,
      PaymentStatus.partial => BadgeKind.partial,
      PaymentStatus.unpaid => BadgeKind.unpaid,
    });