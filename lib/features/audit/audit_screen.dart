import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/empty_state.dart';

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Activity / Audit Trail',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                            Text('${store.audits.length} recorded actions — nothing is silently deleted or overwritten',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: store.audits.isEmpty
                  ? const EmptyState(icon: Icons.history, title: 'No activity recorded')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: store.audits.length,
                      itemBuilder: (ctx, i) => _AuditTile(log: store.audits[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditLog log;
  const _AuditTile({required this.log});

  (IconData, Color) _meta() {
    switch (log.action) {
      case AuditActionType.taskCreated:
        return (Icons.add_task, const Color(0xFF2E7D32));
      case AuditActionType.workerAdded:
        return (Icons.person_add_alt_1, const Color(0xFF0277BD));
      case AuditActionType.calculationSaved:
        return (Icons.calculate_outlined, const Color(0xFF6A1B9A));
      case AuditActionType.allocationCreated:
        return (Icons.handshake_outlined, const Color(0xFF2E7D32));
      case AuditActionType.allocationModified:
        return (Icons.edit_note, const Color(0xFF6A1B9A));
      case AuditActionType.adjustmentMade:
        return (Icons.swap_horiz, const Color(0xFF6A1B9A));
      case AuditActionType.paymentCreated:
      case AuditActionType.paymentUpdated:
        return (Icons.payments_outlined, const Color(0xFF2E7D32));
      case AuditActionType.collectorAssigned:
        return (Icons.person_pin_circle, const Color(0xFF0277BD));
      case AuditActionType.collectionCreated:
        return (Icons.arrow_downward, const Color(0xFF0277BD));
      case AuditActionType.handoverCompleted:
        return (Icons.verified_outlined, const Color(0xFF2E7D32));
      case AuditActionType.workZoneCreated:
        return (Icons.gps_fixed, const Color(0xFF0277BD));
      case AuditActionType.workProgressUpdated:
        return (Icons.track_changes, const Color(0xFF0277BD));
      case AuditActionType.settingsUpdated:
        return (Icons.settings, const Color(0xFF546E7A));
      case AuditActionType.login:
        return (Icons.login, const Color(0xFF546E7A));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final (icon, color) = _meta();
    final worker = store.workerName(log.workerId);
    final collector = store.workerName(log.collectionId);
    final task = store.taskTitle(log.taskId);
    var summary = 'Task: $task';
    switch (log.action) {
      case AuditActionType.adjustmentMade:
        final from = log.oldValue['allocatedAmount'];
        final to = log.newValue['allocatedAmount'];
        summary = 'Worker: $worker\nTSh ${_amt(from)} → TSh ${_amt(to)}${log.reason != null ? '\nReason: ${log.reason}' : ''}';
      case AuditActionType.paymentCreated:
      case AuditActionType.paymentUpdated:
        summary = 'Worker: $worker\nAmount: TSh ${_amt(log.newValue['amount'])}';
      case AuditActionType.collectionCreated:
        summary = 'Collector: $collector\nFor worker: $worker\nAmount: TSh ${_amt(log.newValue['amount'])}';
      case AuditActionType.handoverCompleted:
        summary = 'Collector: $collector\nReceived by: $worker\nAmount: TSh ${_amt(log.newValue['amount'])}';
      case AuditActionType.calculationSaved:
        summary = 'Task: $task\nExpected: TSh ${_amt(log.newValue['expectedAmount'])}';
      default:
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          leading: CircleAvatar(radius: 17, backgroundColor: color.withValues(alpha: 0.14), child: Icon(icon, size: 18, color: color)),
          title: Row(
            children: [
              Expanded(
                child: Text(log.action.label,
                    style: TextStyle(fontWeight: FontWeight.w700, color: color)),
              ),
              Text(fmtDateTime(log.createdAt), style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          subtitle: Text('by ${log.actor}', style: Theme.of(context).textTheme.labelSmall),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary),
                  if (log.oldValue.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Old: ${log.oldValue}', style: Theme.of(context).textTheme.labelSmall),
                    ),
                  if (log.newValue.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('New: ${log.newValue}', style: Theme.of(context).textTheme.labelSmall),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _amt(dynamic v) => v is num ? fmtMoneyPlain(v.round()) : '${v ?? 0}';
}