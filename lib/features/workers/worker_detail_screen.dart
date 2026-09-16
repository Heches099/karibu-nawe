import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../models/allocation.dart';
import '../../models/enums.dart';
import '../../models/payment.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/forms.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../allocations/allocation_sheets.dart';
import '../collections/collector_summary_screen.dart';
import '../payments/payment_sheet.dart';
import '../tasks/task_detail_screen.dart';

class WorkerDetailScreen extends StatelessWidget {
  final String workerId;
  const WorkerDetailScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final worker = store.workerById(workerId);
    if (worker == null) {
      return const Scaffold(body: Center(child: Text('Worker not found.')));
    }
    final money = store.summary.workerMoney(
      workerId: worker.id,
      allocations: store.allocations,
      payments: store.payments,
      collections: store.collections,
      handovers: store.handovers,
    );
    final myAllocs = store.allocations.where((a) => a.workerId == worker.id).toList();
    final cols = store.collectionsByCollector(worker.id);

    return Scaffold(
      appBar: AppBar(title: Text(worker.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                    child: Text(worker.name[0].toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(worker.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        if (worker.phone.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 14),
                              const SizedBox(width: 4),
                              Text(worker.phone),
                            ],
                          ),
                        Text('Collected for others: ${money.collectionCount} · Handed over: ${money.handoverCount}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (money.pendingHandover > 0)
                    const StatusBadge(BadgeKind.pending, label: 'Holding money'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: InfoTile(icon: Icons.gavel, color: const Color(0xFF6A1B9A), label: 'Allocated (own)', value: fmtMoney(money.allocated.round()))),
                  const SizedBox(width: 8),
                  Expanded(child: InfoTile(icon: Icons.trending_up, color: const Color(0xFF2E7D32), label: 'Paid (own)', value: fmtMoney(money.paid.round()))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: InfoTile(icon: Icons.account_balance_wallet, color: money.remaining > 0 ? const Color(0xFFEF6C00) : const Color(0xFF2E7D32), label: 'Remaining (own)', value: fmtMoney(money.remaining.round()))),
                  const SizedBox(width: 8),
                  Expanded(child: InfoTile(icon: Icons.arrow_downward, color: const Color(0xFF0277BD), label: 'Collected for others', value: fmtMoney(money.collectedForOthers.round()))),
                  const SizedBox(width: 8),
                  Expanded(child: InfoTile(icon: Icons.hourglass_empty, color: money.pendingHandover > 0 ? const Color(0xFFEF6C00) : const Color(0xFF2E7D32), label: 'Pending handover', value: fmtMoney(money.pendingHandover.round()))),
                ],
              ),

              const SizedBox(height: 24),
              const SectionHeader(title: 'CURRENT TASKS'),
              const SizedBox(height: 10),
              if (myAllocs.isEmpty)
                const EmptyState(icon: Icons.work_outline, title: 'No active work', message: 'This worker has not been allocated on any task yet.')
              else
                for (final a in myAllocs) ...[
                  _OwnTaskTile(allocation: a),
                  const SizedBox(height: 10),
                ],

              const SizedBox(height: 24),
              SectionHeader(
                title: 'MONEY COLLECTED FOR OTHERS',
                trailing: cols.isNotEmpty
                    ? TextButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CollectorSummaryScreen(collectorId: worker.id),
                        )),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Collector view'),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              if (cols.isEmpty)
                const EmptyState(icon: Icons.arrow_downward, title: 'Not collecting for anyone', message: 'Own earnings above are separate from any money held on behalf of others.')
              else ...[
                AppCard(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: [
                      for (final entry in _groupByWorker(cols).entries)
                        ListTile(
                          dense: true,
                          title: Text(store.workerName(entry.key)),
                          leading: const Icon(Icons.person_outline),
                          trailing: Text(
                            fmtMoney(entry.value.fold<double>(0, (s, c) => s + c.amount).round()),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total holding for others', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            MoneyText(money.collectedForOthers, style: Theme.of(context).textTheme.titleSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (money.pendingHandover > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CollectorSummaryScreen(collectorId: worker.id),
                      )),
                      icon: const Icon(Icons.verified_outlined),
                      label: Text('Complete handover — ${fmtMoney(money.pendingHandover.round())} pending'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<Collection>> _groupByWorker(List<Collection> cols) {
    final map = <String, List<Collection>>{};
    for (final c in cols) {
      (map[c.workerId] ??= []).add(c);
    }
    return map;
  }
}

class _OwnTaskTile extends StatelessWidget {
  final Allocation allocation;
  const _OwnTaskTile({required this.allocation});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final task = store.taskById(allocation.taskId);
    if (task == null) return const SizedBox.shrink();
    final wt = store.workTypeOf(task);
    final calc = store.calculationFor(task.id);
    final paid = store.totalPaidFor(taskId: allocation.taskId, workerId: allocation.workerId);
    final remaining = allocation.allocatedAmount - paid;
    final status = store.paymentStatusFor(taskId: allocation.taskId, workerId: allocation.workerId, allocated: allocation.allocatedAmount);
    final diff = allocation.allocatedAmount - allocation.expectedAmount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(task.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
                StatusBadge(switch (status) {
                  PaymentStatus.paid => BadgeKind.paid,
                  PaymentStatus.partial => BadgeKind.partial,
                  PaymentStatus.unpaid => BadgeKind.unpaid,
                }),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${wt?.name ?? '—'} · ${task.field} · ${fmtDate(task.workDate)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            if (calc != null)
              Text('Area: ${fmtArea((calc.outputs['area'] as num?)?.toDouble() ?? 0)}',
                  style: Theme.of(context).textTheme.bodySmall),
            Row(
              children: [
                Expanded(child: _stat(context, 'Expected', fmtMoney(allocation.expectedAmount.round()))),
                Expanded(child: _stat(context, 'Allocated', fmtMoney(allocation.allocatedAmount.round()))),
                if (diff.abs() > 0.001) Expanded(child: _stat(context, 'Difference', '${fmtSigned(diff)}', color: const Color(0xFF6A1B9A))),
                Expanded(child: _stat(context, 'Paid', fmtMoney(paid.round()))),
                Expanded(child: _stat(context, 'Remaining', fmtMoney(remaining.round()))),
              ],
            ),
            if (diff.abs() > 0.001)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _reasonText(store),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6A1B9A)),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (remaining > 0)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: () {
                      final worker = store.workerById(allocation.workerId);
                      if (worker != null) showAppSheet(context, PaymentSheet(task: task, worker: worker), title: 'Record Payment');
                    },
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Pay'),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: () => showAppSheet(context, AllocationHistorySheet(allocation: allocation), title: 'Activity / History'),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );

  String _reasonText(AppStore store) {
    final adj = store.adjustmentsFor(allocation.id).firstOrNull;
    final reason = adj?.reason;
    return (reason ?? '').isNotEmpty ? 'Adjusted: $reason' : 'Adjusted allocation';
  }
}