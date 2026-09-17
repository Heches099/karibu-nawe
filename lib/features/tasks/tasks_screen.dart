import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/status_badge.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _search = TextEditingController();
  String _query = '';
  TaskStatus? _statusFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Task> _visible(AppStore store) {
    final q = _query.trim().toLowerCase();
    return store.tasks.where((t) {
      if (_statusFilter != null && t.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.field.toLowerCase().contains(q) ||
          store.workTypeById(t.workTypeId)?.name.toLowerCase().contains(q) == true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final visible = _visible(store);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Tasks',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      ),
                      FilledButton.icon(
                        onPressed: () => _createTask(context),
                        icon: const Icon(Icons.add),
                        label: const Text('New Task'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by title, work type or field…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        _statusChip(context, null, 'All'),
                        _statusChip(context, TaskStatus.active, 'Active'),
                        _statusChip(context, TaskStatus.completed, 'Completed'),
                        _statusChip(context, TaskStatus.cancelled, 'Cancelled'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: 'No tasks match',
                      message: 'Create a new farm task to get started.',
                    )
                  : (isWide
                      ? _TaskTable(tasks: visible)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          itemCount: visible.length,
                          itemBuilder: (ctx, i) => _TaskCard(task: visible[i]),
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, TaskStatus? status, String label) {
    final selected = _statusFilter == status || (_statusFilter == null && status == null);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = status),
    );
  }

  void _createTask(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskFormScreen()));
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wt = store.workTypeById(task.workTypeId);
    final summary = store.summary.summarizeTask(
      taskId: task.id,
      calculations: store.calculations,
      allocations: store.allocations,
      payments: store.payments,
      collections: store.collections,
      handovers: store.handovers,
    );
    final badge = switch (task.status) {
      TaskStatus.active => BadgeKind.active,
      TaskStatus.completed => BadgeKind.completed,
      TaskStatus.cancelled => BadgeKind.cancelled,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: task.id),
          )),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(task.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    StatusBadge(badge),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _chip(context, Icons.category_outlined, wt?.name ?? '—'),
                    _chip(context, Icons.place_outlined, task.field),
                    _chip(context, Icons.event, fmtDate(task.workDate)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${summary.workerCount} worker(s)',
                        style: Theme.of(context).textTheme.bodySmall),
                    Row(
                      children: [
                        MoneyText(summary.expected, compact: true, style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(width: 8),
                        Text('expected',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressRow(value: summary.allocated, paid: summary.paid),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      );
}

class _ProgressRow extends StatelessWidget {
  final double value;
  final double paid;
  const _ProgressRow({required this.value, required this.paid});

  @override
  Widget build(BuildContext context) {
    final total = value <= 0 ? 0 : (paid / value).clamp(0.0, 1.0);
    final color = total >= 1
        ? const Color(0xFF2E7D32)
        : total > 0
            ? const Color(0xFFF9A825)
            : Theme.of(context).colorScheme.outlineVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total.toDouble(),
            minHeight: 6,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Paid ${fmtMoney(paid.round())} of ${fmtMoney(value.round())}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TaskTable extends StatelessWidget {
  final List<Task> tasks;
  const _TaskTable({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1000),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Task')),
                  DataColumn(label: Text('Work Type')),
                  DataColumn(label: Text('Field')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Expected'), numeric: true),
                  DataColumn(label: Text('Allocated'), numeric: true),
                  DataColumn(label: Text('Paid'), numeric: true),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final task in tasks)
                    DataRow(
                      onSelectChanged: (_) => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(taskId: task.id),
                      )),
                      cells: [
                        DataCell(Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(store.workTypeById(task.workTypeId)?.name ?? '—')),
                        DataCell(Text(task.field)),
                        DataCell(Text(fmtDate(task.workDate))),
                        DataCell(MoneyText(store.summary.summarizeTask(taskId: task.id, calculations: store.calculations, allocations: store.allocations, payments: store.payments, collections: store.collections, handovers: store.handovers).expected, compact: true)),
                        DataCell(MoneyText(store.summary.summarizeTask(taskId: task.id, calculations: store.calculations, allocations: store.allocations, payments: store.payments, collections: store.collections, handovers: store.handovers).allocated, compact: true)),
                        DataCell(MoneyText(store.summary.summarizeTask(taskId: task.id, calculations: store.calculations, allocations: store.allocations, payments: store.payments, collections: store.collections, handovers: store.handovers).paid, compact: true)),
                        DataCell(StatusBadge(switch (task.status) {
                          TaskStatus.active => BadgeKind.active,
                          TaskStatus.completed => BadgeKind.completed,
                          TaskStatus.cancelled => BadgeKind.cancelled,
                        })),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}