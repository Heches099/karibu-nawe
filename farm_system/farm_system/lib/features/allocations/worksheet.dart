import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/allocation.dart';
import '../../state/app_state.dart';
import '../../shared/widgets/status_badge.dart';
import 'allocation_dialogs.dart';
import '../workers/worker_detail_screen.dart';

/// The main operational table from spec section 8. Uses a responsive
/// table on wide screens and a stack of cards on mobile, both reading
/// from the exact same data so nothing can drift between layouts
/// (spec section 30).
class Worksheet extends StatelessWidget {
  final String taskId;
  const Worksheet({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final allocations = app.allocationRepo.forTask(taskId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Worksheet (${allocations.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              FilledButton.icon(
                onPressed: () => showAddWorkerDialog(context, taskId),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add Worker'),
              ),
            ],
          ),
        ),
        if (allocations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No workers added yet.', style: TextStyle(color: Colors.grey[600])),
              ),
            ),
          )
        else
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return _WorksheetTable(taskId: taskId, allocations: allocations);
            }
            return Column(
              children: allocations
                  .map((a) => _WorkerCard(taskId: taskId, allocation: a))
                  .toList(),
            );
          }),
      ],
    );
  }
}

class _WorksheetTable extends StatelessWidget {
  final String taskId;
  final List<Allocation> allocations;
  const _WorksheetTable({required this.taskId, required this.allocations});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('S/N')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Expected')),
            DataColumn(label: Text('Allocated')),
            DataColumn(label: Text('Adj.')),
            DataColumn(label: Text('Paid')),
            DataColumn(label: Text('Remaining')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Collector')),
            DataColumn(label: Text('')),
          ],
          rows: List.generate(allocations.length, (i) {
            final a = allocations[i];
            final paid = app.paymentService.totalPaid(a.id);
            final remaining = app.paymentService.remaining(a);
            final status = app.paymentService.statusFor(a);
            final collection = app.collectionRepo.forAllocation(a.id).firstOrNull;
            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => WorkerDetailScreen(workerId: a.workerId))),
                child: Text(app.workerName(a.workerId), style: const TextStyle(fontWeight: FontWeight.w600)),
              )),
              DataCell(Text(CurrencyFormatter.format(a.expectedAmount))),
              DataCell(Text(CurrencyFormatter.format(a.allocatedAmount))),
              DataCell(a.isAdjusted
                  ? Text(CurrencyFormatter.formatSigned(a.difference),
                      style: TextStyle(color: a.difference > 0 ? AppTheme.success : AppTheme.danger, fontWeight: FontWeight.w600))
                  : const Text('—')),
              DataCell(Text(CurrencyFormatter.format(paid))),
              DataCell(Text(CurrencyFormatter.format(remaining))),
              DataCell(StatusBadge.payment(status)),
              DataCell(collection == null
                  ? const Text('—')
                  : Text(app.workerName(collection.collectorWorkerId))),
              DataCell(_RowActions(taskId: taskId, allocation: a)),
            ]);
          }),
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final String taskId;
  final Allocation allocation;
  const _WorkerCard({required this.taskId, required this.allocation});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final paid = app.paymentService.totalPaid(allocation.id);
    final remaining = app.paymentService.remaining(allocation);
    final status = app.paymentService.statusFor(allocation);
    final collection = app.collectionRepo.forAllocation(allocation.id).firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => WorkerDetailScreen(workerId: allocation.workerId))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(app.workerName(allocation.workerId),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  StatusBadge.payment(status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _stat('Expected', CurrencyFormatter.format(allocation.expectedAmount))),
                  Expanded(child: _stat('Allocated', CurrencyFormatter.format(allocation.allocatedAmount))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _stat('Paid', CurrencyFormatter.format(paid))),
                  Expanded(child: _stat('Remaining', CurrencyFormatter.format(remaining))),
                ],
              ),
              if (allocation.isAdjusted) ...[
                const SizedBox(height: 8),
                StatusBadge.adjusted(),
              ],
              if (collection != null) ...[
                const SizedBox(height: 8),
                Text('Collected by ${app.workerName(collection.collectorWorkerId)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _RowActions(taskId: taskId, allocation: allocation),
              ),
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

class _RowActions extends StatelessWidget {
  final String taskId;
  final Allocation allocation;
  const _RowActions({required this.taskId, required this.allocation});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        switch (v) {
          case 'adjust':
            showAdjustAllocationDialog(context, allocation);
            break;
          case 'pay':
            showRecordPaymentDialog(context, allocation);
            break;
          case 'collector':
            showAssignCollectorDialog(context, allocation);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'adjust', child: Text('Adjust Allocation')),
        PopupMenuItem(value: 'pay', child: Text('Record Payment')),
        PopupMenuItem(value: 'collector', child: Text('Assign Collector')),
      ],
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
