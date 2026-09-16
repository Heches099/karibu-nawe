import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/task.dart';
import '../../state/app_state.dart';
import '../../shared/widgets/status_badge.dart';
import 'task_detail_screen.dart';
import 'task_form_sheet.dart';

class TaskListScreen extends StatefulWidget {
  final bool openCreate;
  const TaskListScreen({super.key, this.openCreate = false});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.openCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => TaskFormSheet.show(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    var tasks = app.taskRepo.getAll()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      tasks = tasks
          .where((t) =>
              t.title.toLowerCase().contains(q) || t.field.toLowerCase().contains(q))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TaskFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by title or field',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? _EmptyState(onCreate: () => TaskFormSheet.show(context))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _TaskCard(task: tasks[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final workType = app.workTypeRepo.getById(task.workTypeId);
    final calc = app.calculationRepo.activeForTask(task.id);
    final allocations = app.allocationRepo.forTask(task.id);
    final paid = allocations.fold<int>(0, (s, a) => s + app.paymentService.totalPaid(a.id));
    final allocated = allocations.fold<int>(0, (s, a) => s + a.allocatedAmount);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(task.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  StatusBadge.task(task.status),
                ],
              ),
              const SizedBox(height: 6),
              Text('${workType?.name ?? task.workTypeId} · ${task.field} · ${DateFormatter.date(task.workDate)}',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _mini('Measured', calc == null ? '—' : '${calc.measuredValue.toStringAsFixed(0)} ${calc.measuredUnit}'),
                  _mini('Expected', calc == null ? '—' : CurrencyFormatter.format(calc.expectedAmount)),
                  _mini('Allocated', CurrencyFormatter.format(allocated)),
                  _mini('Paid', CurrencyFormatter.format(paid)),
                  _mini('Workers', '${allocations.length}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.agriculture_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No tasks yet', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
          const SizedBox(height: 4),
          Text('Create your first farm task to get started', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('New Task')),
        ],
      ),
    );
  }
}
