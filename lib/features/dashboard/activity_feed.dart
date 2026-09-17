import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/empty_state.dart';
import '../tasks/task_detail_screen.dart';

class ActivityFeed extends StatelessWidget {
  final int? limit;
  final bool compact;
  final String? taskId;

  const ActivityFeed({super.key, this.limit, this.compact = false, this.taskId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final all = taskId == null ? store.audits : store.audits.where((a) => a.taskId == taskId).toList();
    final logs = all.take(limit ?? all.length).toList();
    if (logs.isEmpty) {
      return const EmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'No activity yet',
        message: 'Actions like payments, allocations and handovers will appear here live.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < logs.length; i++)
          _ActivityTile(log: logs[i], showConnector: i < logs.length - 1),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final AuditLog log;
  final bool showConnector;

  const _ActivityTile({required this.log, required this.showConnector});

  (IconData, Color, String) _summary(AppStore store) {
    final s = store;
    final worker = s.workerName(log.workerId);
    final task = s.taskTitle(log.taskId);
    switch (log.action) {
      case AuditActionType.taskCreated:
        return (Icons.add_task, const Color(0xFF2E7D32), 'New task created\n${log.newValue['title'] ?? task}');
      case AuditActionType.workerAdded:
        return (Icons.person_add_alt_1, const Color(0xFF0277BD), 'New worker added\n${log.newValue['name'] ?? worker}');
      case AuditActionType.calculationSaved:
        final amt = log.newValue['expectedAmount'];
        return (Icons.calculate_outlined, const Color(0xFF6A1B9A), 'Calculation saved · expected TSh ${amount(amt)}\n$task');
      case AuditActionType.allocationCreated:
        return (Icons.handshake_outlined, const Color(0xFF2E7D32), '$worker allocation registered\n$task');
      case AuditActionType.adjustmentMade:
        final from = log.oldValue['allocatedAmount'];
        final to = log.newValue['allocatedAmount'];
        return (Icons.swap_horiz, const Color(0xFF6A1B9A), 'Allocation changed\nTSh ${amount(from)} → TSh ${amount(to)}${log.reason != null ? '\nReason: ${log.reason}' : ''}');
      case AuditActionType.allocationModified:
        return (Icons.edit_note, const Color(0xFF6A1B9A), 'Allocation updated\n$worker on $task');
      case AuditActionType.paymentCreated:
        final amt = log.newValue['amount'];
        return (Icons.payments_outlined, const Color(0xFF2E7D32), '$worker received TSh ${amount(amt)}');
      case AuditActionType.paymentUpdated:
        return (Icons.edit, const Color(0xFF2E7D32), 'Payment updated\n$worker');
      case AuditActionType.collectorAssigned:
        return (Icons.person_pin_circle, const Color(0xFF0277BD), 'Collector assigned\n$worker');
      case AuditActionType.collectionCreated:
        final amt = log.newValue['amount'];
        final collector = s.workerName(log.collectionId);
        return (Icons.arrow_downward, const Color(0xFF0277BD), '$collector collected TSh ${amount(amt)} for $worker');
      case AuditActionType.handoverCompleted:
        final amt = log.newValue['amount'];
        final collector = s.workerName(log.collectionId);
        return (Icons.verified_outlined, const Color(0xFF2E7D32), '$collector handed over TSh ${amount(amt)} to $worker');
      case AuditActionType.workZoneCreated:
        return (Icons.gps_fixed, const Color(0xFF0277BD), 'Work zone saved\n${log.newValue['name'] ?? 'New zone'}');
      case AuditActionType.workProgressUpdated:
        return (Icons.track_changes, const Color(0xFF0277BD), 'Work progress updated\n$task');
      case AuditActionType.settingsUpdated:
        return (Icons.settings, const Color(0xFF546E7A), 'Settings updated');
      case AuditActionType.login:
        return (Icons.login, const Color(0xFF546E7A), '${log.actor} signed in');
    }
  }

  String amount(dynamic v) {
    if (v is num) return fmtMoneyPlain(v.round());
    return "${v ?? 0}";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.read<AppStore>();
    final (icon, color, text) = _summary(store);
    final lines = text.split('\n');
    return InkWell(
      onTap: log.taskId == null || log.action == AuditActionType.taskCreated
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TaskDetailScreen(taskId: log.taskId!),
            )),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, size: 17, color: color),
                ),
                if (showConnector)
                  Container(
                    width: 2,
                    height: 40,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Text(
                      lines[i],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
                            color: scheme.onSurface,
                          ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        timeAgo(log.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'by ${log.actor}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                fmtDateTime(log.createdAt).split(' ').first,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}