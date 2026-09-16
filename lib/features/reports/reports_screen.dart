import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../models/allocation.dart';
import '../../models/enums.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/period_selector.dart';
import '../../shared/widgets/status_badge.dart';
import '../collections/collector_summary_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateRange? _range;
  String? _workTypeId;
  String? _workerId;
  PaymentStatus? _paymentStatus;
  bool _onlyAdjusted = false;

  List<Allocation> _filtered(AppStore store) {
    final range = _range;
    final ids = <String>{};
    for (final t in store.tasks) {
      if (range == null || inRange(t.workDate, range.from, range.to)) {
        ids.add(t.id);
      }
    }
    return store.allocations.where((a) {
      if (!ids.contains(a.taskId)) return false;
      if (_workTypeId != null) {
        final task = store.taskById(a.taskId);
        if (task == null || task.workTypeId != _workTypeId) return false;
      }
      if (_workerId != null && a.workerId != _workerId) return false;
      final paid = store.totalPaidFor(taskId: a.taskId, workerId: a.workerId);
      final st = derivePaymentStatus(a.allocatedAmount, paid);
      if (_paymentStatus != null && st != _paymentStatus) return false;
      if (_onlyAdjusted && (a.allocatedAmount - a.expectedAmount).abs() < 0.001) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final allocs = _filtered(store);
    final taskIds = allocs.map((a) => a.taskId).toSet();

    double expected = 0, allocated = 0, adj = 0, paid = 0, area = 0;
    final collectors = <String, double>{};
    for (final a in allocs) {
      expected += a.expectedAmount;
      allocated += a.allocatedAmount;
      adj += a.allocatedAmount - a.expectedAmount;
      paid += store.totalPaidFor(taskId: a.taskId, workerId: a.workerId);
      final calc = store.calculationFor(a.taskId);
      area += (calc?.outputs['area'] as num?)?.toDouble() ?? 0;
    }
    var collected = 0.0;
    for (final c in store.collections) {
      if (!taskIds.contains(c.taskId)) continue;
      if (_workerId != null && c.collectorId != _workerId) continue;
      collectors[c.collectorId] = (collectors[c.collectorId] ?? 0) + c.amount;
      collected += c.amount;
    }
    var handedOver = 0.0;
    for (final h in store.handovers) {
      if (taskIds.contains(h.taskId)) handedOver += h.amount;
    }

    void assignWorkerFilter(String? id) {
      setState(() => _workerId = id);
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Reports', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    PeriodSelector(initial: ReportPeriod.thisMonth, onChanged: (r) => setState(() => _range = r)),
                    const SizedBox(height: 12),
                    _Filters(
                      workTypeId: _workTypeId,
                      workerId: _workerId,
                      paymentStatus: _paymentStatus,
                      onlyAdjusted: _onlyAdjusted,
                      onWorkType: (v) => setState(() => _workTypeId = v),
                      onWorker: (v) => setState(() => _workerId = v),
                      onPaymentStatus: (v) => setState(() => _paymentStatus = v),
                      onAdjusted: (v) => setState(() => _onlyAdjusted = v),
                      onOpenWorker: assignWorkerFilter,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width >= 1000 ? 4 : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.1,
                ),
                delegate: SliverChildListDelegate([
                  _sumCard(context, Icons.landscape, const Color(0xFF6A1B9A), 'Area', '${area.round()} m²'),
                  _sumCard(context, Icons.functions, const Color(0xFF2E7D32), 'Expected', fmtMoney(expected.round())),
                  _sumCard(context, Icons.handshake, const Color(0xFF6A1B9A), 'Allocated', fmtMoney(allocated.round())),
                  _sumCard(context, Icons.swap_horiz, const Color(0xFF6A1B9A), 'Adjustments', fmtSigned(adj.round())),
                  _sumCard(context, Icons.trending_up, const Color(0xFF2E7D32), 'Paid', fmtMoney(paid.round())),
                  _sumCard(context, Icons.account_balance_wallet, const Color(0xFFEF6C00), 'Remaining', fmtMoney((allocated - paid).round())),
                  _sumCard(context, Icons.arrow_downward, const Color(0xFF0277BD), 'Collected For Others', fmtMoney(collected.round())),
                  _sumCard(context, Icons.hourglass_empty, const Color(0xFFEF6C00), 'Pending Handover', fmtMoney((collected - handedOver).round())),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: SectionHeader(
                  title: 'COLLECTOR LEDGERS',
                  trailing: Text('${collectors.length} collector(s)', style: Theme.of(context).textTheme.labelMedium),
                ),
              ),
            ),
            if (collectors.isEmpty)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('No collections in this period.')))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) {
                    final entry = collectors.entries.elementAt(i);
                    final handed = store.handovers.where((h) => taskIds.contains(h.taskId) && h.collectorId == entry.key).fold<double>(0, (s, h) => s + h.amount);
                    final pending = entry.value - handed;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0277BD).withValues(alpha: 0.12),
                            child: const Icon(Icons.person_pin_circle, color: Color(0xFF0277BD)),
                          ),
                          title: Text(store.workerName(entry.key), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('Collected ${fmtMoneyPlain(entry.value.round())} · Handed ${fmtMoneyPlain(handed.round())}'),
                          trailing: pending > 0
                              ? const StatusBadge(BadgeKind.pending, label: 'Pending')
                              : const StatusBadge(BadgeKind.completed, label: 'Clean'),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CollectorSummaryScreen(collectorId: entry.key),
                          )),
                        ),
                      ),
                    );
                  }, childCount: collectors.length),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: SectionHeader(
                  title: 'WORKER ALLOCATIONS',
                  trailing: Text('${allocs.length} row(s)', style: Theme.of(context).textTheme.labelMedium),
                ),
              ),
            ),
            if (allocs.isEmpty)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: EmptyState(icon: Icons.search_off, title: 'No allocations match', message: 'Try widening the date range or clearing filters.')))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) => _AllocRow(allocation: allocs[i]), childCount: allocs.length),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _sumCard(BuildContext context, IconData icon, Color color, String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: color.withValues(alpha: 0.14), child: Icon(icon, size: 17, color: color)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Filters extends StatelessWidget {
  final String? workTypeId;
  final String? workerId;
  final PaymentStatus? paymentStatus;
  final bool onlyAdjusted;
  final ValueChanged<String?> onWorkType;
  final ValueChanged<String?> onWorker;
  final ValueChanged<PaymentStatus?> onPaymentStatus;
  final ValueChanged<bool> onAdjusted;
  final ValueChanged<String?> onOpenWorker;

  const _Filters({
    required this.workTypeId,
    required this.workerId,
    required this.paymentStatus,
    required this.onlyAdjusted,
    required this.onWorkType,
    required this.onWorker,
    required this.onPaymentStatus,
    required this.onAdjusted,
    required this.onOpenWorker,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String?>(
          value: workTypeId,
          borderRadius: BorderRadius.circular(12),
          onChanged: onWorkType,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All Work Types')),
            for (final wt in store.workTypes)
              DropdownMenuItem(value: wt.id, child: Text(wt.name)),
          ],
        ),
        DropdownButton<String?>(
          value: workerId,
          borderRadius: BorderRadius.circular(12),
          onChanged: onWorker,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All Workers')),
            for (final w in store.workers)
              DropdownMenuItem(value: w.id, child: Text(w.name)),
          ],
        ),
        DropdownButton<PaymentStatus?>(
          value: paymentStatus,
          borderRadius: BorderRadius.circular(12),
          onChanged: onPaymentStatus,
          items: [
            const DropdownMenuItem<PaymentStatus?>(value: null, child: Text('All Payment Status')),
            for (final s in PaymentStatus.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
        ),
        FilterChip(
          avatar: const Icon(Icons.swap_horiz, size: 16),
          label: const Text('Adjusted only'),
          selected: onlyAdjusted,
          onSelected: onAdjusted,
        ),
      ],
    );
  }
}

class _AllocRow extends StatelessWidget {
  final Allocation allocation;
  const _AllocRow({required this.allocation});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final worker = store.workerById(allocation.workerId);
    final task = store.taskById(allocation.taskId);
    final paid = store.totalPaidFor(taskId: allocation.taskId, workerId: allocation.workerId);
    final status = store.paymentStatusFor(taskId: allocation.taskId, workerId: allocation.workerId, allocated: allocation.allocatedAmount);
    final diff = allocation.allocatedAmount - allocation.expectedAmount;
    final adj = store.adjustmentsFor(allocation.id).firstOrNull;
    final calc = store.calculationFor(allocation.taskId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(task?.title ?? '—', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text('${store.workTypeById(task?.workTypeId)?.name ?? ''} · ${task?.field ?? ''} · ${task == null ? '' : fmtDate(task.workDate)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${calc == null ? '' : fmtArea((calc.outputs['area'] as num?)?.toDouble() ?? 0)}',
                      style: Theme.of(context).textTheme.labelMedium),
                  Text(fmtMoney(allocation.expectedAmount.round()), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width >= 800 ? 120 : 90,
              child: Align(alignment: Alignment.centerRight, child: MoneyText(allocation.allocatedAmount, compact: true)),
            ),
            if (MediaQuery.of(context).size.width >= 700)
              SizedBox(width: 70, child: Align(alignment: Alignment.centerRight, child: diff.abs() > 0.001 ? MoneyText(diff, showSign: true, compact: true, bold: false) : const Text('—'))),
            if (MediaQuery.of(context).size.width >= 800)
              Expanded(child: Text(adj?.reason ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            SizedBox(
              width: 80,
              child: Align(alignment: Alignment.centerRight, child: MoneyText(paid, compact: true)),
            ),
            const SizedBox(width: 10),
            StatusBadge(switch (status) {
              PaymentStatus.paid => BadgeKind.paid,
              PaymentStatus.partial => BadgeKind.partial,
              PaymentStatus.unpaid => BadgeKind.unpaid,
            }),
          ],
        ),
      ),
    );
  }
}