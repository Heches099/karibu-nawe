import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/summary_card.dart';
import '../../state/app_state.dart';
import '../calculator/calculator_form.dart';
import '../allocations/worksheet.dart';
import '../audit/audit_screen.dart';

/// TASK HEADER / EXPECTED SUMMARY / SECTIONS structure from spec section 21.
class TaskDetailScreen extends StatelessWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final task = app.taskRepo.getById(taskId);
    if (task == null) {
      return const Scaffold(body: Center(child: Text('Task not found')));
    }
    final workType = app.workTypeRepo.getById(task.workTypeId);
    final calc = app.calculationRepo.activeForTask(taskId);
    final allocations = app.allocationRepo.forTask(taskId);
    final expected = allocations.fold<int>(0, (s, a) => s + a.expectedAmount);
    final allocated = allocations.fold<int>(0, (s, a) => s + a.allocatedAmount);
    final paid = allocations.fold<int>(0, (s, a) => s + app.paymentService.totalPaid(a.id));
    final remaining = allocated - paid;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(task.title, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Calculator'),
            Tab(text: 'Worksheet'),
            Tab(text: 'Activity'),
          ]),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(
              task: task,
              workTypeName: workType?.name ?? task.workTypeId,
              calcArea: calc?.measuredValue,
              calcUnit: calc?.measuredUnit,
              expected: calc?.expectedAmount ?? expected,
              allocated: allocated,
              paid: paid,
              remaining: remaining,
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: workType == null
                  ? const Text('Work type not found')
                  : CalculatorForm(taskId: taskId, workType: workType, existing: calc),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Worksheet(taskId: taskId),
            ),
            _ActivityTab(taskId: taskId),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final dynamic task;
  final String workTypeName;
  final double? calcArea;
  final String? calcUnit;
  final int expected;
  final int allocated;
  final int paid;
  final int remaining;

  const _OverviewTab({
    required this.task,
    required this.workTypeName,
    required this.calcArea,
    required this.calcUnit,
    required this.expected,
    required this.allocated,
    required this.paid,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(task.title,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    StatusBadge.task(task.status),
                  ],
                ),
                if (task.description != null) ...[
                  const SizedBox(height: 8),
                  Text(task.description, style: TextStyle(color: Colors.grey[700])),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 16, runSpacing: 8, children: [
                  _info(Icons.category_outlined, workTypeName),
                  _info(Icons.place_outlined, task.field),
                  _info(Icons.event, DateFormatter.date(task.workDate)),
                ]),
                if (task.notes != null) ...[
                  const SizedBox(height: 12),
                  Text('Notes: ${task.notes}', style: TextStyle(color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Expected Summary', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            SummaryCard(
              label: 'Measured',
              value: calcArea == null ? 'Not calculated' : '${calcArea!.toStringAsFixed(0)} $calcUnit',
              icon: Icons.straighten,
              color: Colors.blueGrey,
            ),
            SummaryCard(
              label: 'Expected',
              value: CurrencyFormatter.format(expected),
              icon: Icons.calculate_outlined,
              color: Colors.blueGrey,
            ),
            SummaryCard(
              label: 'Allocated',
              value: CurrencyFormatter.format(allocated),
              icon: Icons.assignment_ind_outlined,
              color: Colors.indigo,
            ),
            SummaryCard(
              label: 'Paid',
              value: CurrencyFormatter.format(paid),
              icon: Icons.payments_outlined,
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SummaryCard(
          label: 'Remaining To Pay',
          value: CurrencyFormatter.format(remaining),
          icon: Icons.pending_actions,
          color: remaining > 0 ? Colors.orange : Colors.green,
        ),
      ],
    );
  }

  Widget _info(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: Colors.grey[700])),
        ],
      );
}

class _ActivityTab extends StatelessWidget {
  final String taskId;
  const _ActivityTab({required this.taskId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final logs = app.auditRepo.forTask(taskId);
    if (logs.isEmpty) {
      return Center(child: Text('No activity yet', style: TextStyle(color: Colors.grey[600])));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (_, i) => AuditTile(log: logs[i]),
    );
  }
}
