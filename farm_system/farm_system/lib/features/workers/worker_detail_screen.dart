import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../shared/widgets/status_badge.dart';
import '../../state/app_state.dart';
import '../tasks/task_detail_screen.dart';
import '../allocations/allocation_dialogs.dart';

/// Worker detail (spec section 22). Crucially keeps the worker's OWN
/// earnings completely separate from money they are holding for others
/// (Rule 10) — two distinct sections, never summed together.
class WorkerDetailScreen extends StatelessWidget {
  final String workerId;
  const WorkerDetailScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final worker = app.worker(workerId);
    if (worker == null) return const Scaffold(body: Center(child: Text('Worker not found')));

    final allocations = app.allocationRepo.forWorker(workerId);
    final collectorSummary = app.collectorSummary(workerId);

    return Scaffold(
      appBar: AppBar(title: Text(worker.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('OWN WORK & EARNINGS',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 1)),
          const SizedBox(height: 10),
          if (allocations.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No work recorded for ${worker.name} yet.', style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else
            ...allocations.map((a) => _WorkCard(allocationId: a.id)),
          const SizedBox(height: 24),
          Text('MONEY COLLECTED FOR OTHERS',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 1)),
          const SizedBox(height: 10),
          if (collectorSummary.lines.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('${worker.name} is not collecting money for anyone.', style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in collectorSummary.lines)
                      InkWell(
                        onTap: line.pendingAmount > 0
                            ? () => showCompleteHandoverDialog(context, line.collection)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(line.forWorkerName)),
                              Text(CurrencyFormatter.format(line.collection.amount),
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 10),
                              StatusBadge.collection(line.collection.status),
                              if (line.pendingAmount > 0) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.chevron_right, size: 16, color: Colors.grey[500]),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL COLLECTED', style: TextStyle(fontWeight: FontWeight.w700)),
                        Text(CurrencyFormatter.format(collectorSummary.totalCollected),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Handed Over', style: TextStyle(color: Colors.grey[700])),
                        Text(CurrencyFormatter.format(collectorSummary.totalHandedOver)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pending Handover', style: TextStyle(color: Colors.orange[800])),
                        Text(CurrencyFormatter.format(collectorSummary.totalPending),
                            style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  final String allocationId;
  const _WorkCard({required this.allocationId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final allocation = app.allocationRepo.getById(allocationId)!;
    final task = app.task(allocation.taskId);
    final calc = app.calculation(allocation.calculationId);
    final paid = app.paymentService.totalPaid(allocation.id);
    final remaining = app.paymentService.remaining(allocation);
    final status = app.paymentService.statusFor(allocation);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: task == null
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(task?.title ?? 'Unknown task', style: const TextStyle(fontWeight: FontWeight.w700))),
                StatusBadge.payment(status),
              ]),
              if (calc != null)
                Text('${calc.measuredValue.toStringAsFixed(0)} ${calc.measuredUnit}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(spacing: 16, runSpacing: 6, children: [
                _stat('Expected', CurrencyFormatter.format(allocation.expectedAmount)),
                _stat('Allocated', CurrencyFormatter.format(allocation.allocatedAmount)),
                if (allocation.isAdjusted)
                  _stat('Difference', CurrencyFormatter.formatSigned(allocation.difference)),
                _stat('Paid', CurrencyFormatter.format(paid)),
                _stat('Remaining', CurrencyFormatter.format(remaining)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
}
