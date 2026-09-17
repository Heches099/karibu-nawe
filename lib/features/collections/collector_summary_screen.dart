import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/forms.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_badge.dart';
import 'collection_sheet.dart';

class CollectorSummaryScreen extends StatelessWidget {
  final String collectorId;
  final String? taskId;

  const CollectorSummaryScreen({super.key, required this.collectorId, this.taskId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final collector = store.workerById(collectorId);
    if (collector == null) return const SizedBox.shrink();

    final collections = <Collection>[];
    for (final c in store.collections) {
      if (c.collectorId == collectorId && (taskId == null || c.taskId == taskId)) collections.add(c);
    }
    final byWorker = <String, double>{};
    for (final c in collections) {
      byWorker[c.workerId] = (byWorker[c.workerId] ?? 0) + c.amount;
    }
    final total = byWorker.values.fold<double>(0, (a, b) => a + b);
    final handedOver = store.handedOverBy(collectorId);
    final pending = store.pendingHandoverBy(collectorId);

    return Scaffold(
      appBar: AppBar(title: Text(collector.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFF0277BD).withValues(alpha: 0.14),
                  child: const Icon(Icons.person_pin_circle, size: 38, color: Color(0xFF0277BD)),
                ),
                const SizedBox(height: 8),
                Text(collector.name.toUpperCase(), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                Text('COLLECTION SUMMARY', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: InfoTile(icon: Icons.arrow_downward, color: const Color(0xFF0277BD), label: 'Collected For Others', value: fmtMoney(total.round()))),
              const SizedBox(width: 8),
              Expanded(child: InfoTile(icon: Icons.verified_outlined, color: const Color(0xFF2E7D32), label: 'Handed Over', value: fmtMoney(handedOver.round()))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: InfoTile(icon: Icons.hourglass_empty, color: pending > 0 ? const Color(0xFFEF6C00) : const Color(0xFF2E7D32), label: 'Pending Handover', value: fmtMoney(pending.round()))),
              const SizedBox(width: 8),
              Expanded(child: InfoTile(icon: Icons.groups, color: const Color(0xFF6A1B9A), label: 'People', value: '${byWorker.length}')),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'COLLECTED FOR'),
          const SizedBox(height: 10),
          for (final entry in byWorker.entries) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(store.workerName(entry.key)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MoneyText(entry.value, compact: true),
                    _pairHandoverBadge(context, store, collector, entry.key, entry.value),
                  ],
                ),
                onTap: () {
                  final worker = store.workerById(entry.key);
                  if (worker != null) showAppSheet(context, _PairHistory(collector, worker), title: 'Collection History');
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (byWorker.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('This worker is not collecting money for anyone.'),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: pending <= 0
                ? null
                : () => showAppSheet(context, HandoverSheet(collector: collector), title: 'Record Handover'),
            icon: const Icon(Icons.verified_outlined),
            label: Text(pending <= 0 ? 'All money handed over' : 'Record Handover — pending ${fmtMoneyPlain(pending.round())}'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _pairHandoverBadge(BuildContext context, AppStore store, Worker collector, String workerId, double collectedAmount) {
    final handed = store.handovers.where((h) => h.collectorId == collector.id && h.workerId == workerId).fold<double>(0, (s, h) => s + h.amount);
    if (handed >= collectedAmount - 0.001) {
      return const Padding(
        padding: EdgeInsets.only(top: 2),
        child: StatusBadge(BadgeKind.completed, label: 'Handed Over'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: StatusBadge(BadgeKind.pending, label: 'Pending handover'),
    );
  }
}

class _PairHistory extends StatelessWidget {
  final Worker collector;
  final Worker worker;
  const _PairHistory(this.collector, this.worker);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cols = store.collections
        .where((c) => c.collectorId == collector.id && c.workerId == worker.id)
        .toList()
      ..sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
    final hans = store.handovers
        .where((h) => h.collectorId == collector.id && h.workerId == worker.id)
        .toList()
      ..sort((a, b) => b.handedAt.compareTo(a.handedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Collections', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          MoneyText(cols.fold<double>(0, (s, c) => s + c.amount)),
        ]),
        const Divider(),
        for (final c in cols)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.arrow_downward, color: Color(0xFF0277BD)),
            title: Text('TSh ${fmtMoneyPlain(c.amount.round())}'),
            subtitle: Text(c.taskId.isEmpty ? '' : store.taskTitle(c.taskId)),
            trailing: Text(fmtDateTime(c.collectedAt), style: Theme.of(context).textTheme.labelSmall),
          ),
        if (cols.isEmpty) const Text('No collections for this pair.'),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Handovers', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          MoneyText(hans.fold<double>(0, (s, h) => s + h.amount)),
        ]),
        const Divider(),
        for (final h in hans)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_outlined, color: Color(0xFF2E7D32)),
            title: Text('TSh ${fmtMoneyPlain(h.amount.round())} ${h.note ?? ''}'),
            trailing: Text(fmtDateTime(h.handedAt), style: Theme.of(context).textTheme.labelSmall),
          ),
        if (hans.isEmpty) const Text('No handovers yet for this pair.'),
      ],
    );
  }
}