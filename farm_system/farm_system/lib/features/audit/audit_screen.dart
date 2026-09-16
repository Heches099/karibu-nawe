import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatter.dart';
import '../../models/audit_log.dart';
import '../../state/app_state.dart';

/// Full, filterable audit trail (spec section 25). Nothing here is ever
/// edited or deleted — this screen only ever appends new rows over time.
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final logs = app.auditRepo.getAll()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Trail')),
      body: logs.isEmpty
          ? Center(child: Text('No audit records yet', style: TextStyle(color: Colors.grey[600])))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (_, i) => AuditTile(log: logs[i]),
            ),
    );
  }
}

class AuditTile extends StatelessWidget {
  final AuditLog log;
  const AuditTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ActionChip(action: log.action),
                const Spacer(),
                Text(DateFormatter.dateTime(log.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(log.description, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (log.workerId != null || log.taskId != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (log.workerId != null) 'Worker: ${app.workerName(log.workerId!)}',
                  if (log.taskId != null) 'Task: ${app.taskTitle(log.taskId!)}',
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (log.oldValue != null || log.newValue != null) ...[
              const SizedBox(height: 4),
              Text(
                '${log.oldValue != null ? 'From: ${log.oldValue}  ' : ''}'
                '${log.newValue != null ? 'To: ${log.newValue}' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (log.reason != null) ...[
              const SizedBox(height: 4),
              Text('Reason: ${log.reason}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 4),
            Text('By ${log.userName}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final dynamic action;
  const _ActionChip({required this.action});

  @override
  Widget build(BuildContext context) {
    final label = action.toString().split('.').last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
