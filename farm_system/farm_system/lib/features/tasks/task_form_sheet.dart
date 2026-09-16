import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/work_type.dart';
import '../../state/app_state.dart';
import 'task_detail_screen.dart';

/// The "SAVE TASK" / "SAVE & OPEN" form from spec section 3, shown as a
/// bottom sheet so it works comfortably on mobile and desktop alike.
class TaskFormSheet extends StatefulWidget {
  const TaskFormSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const TaskFormSheet(),
      );

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _field = TextEditingController();
  final _notes = TextEditingController();
  DateTime _workDate = DateTime.now();
  String? _workTypeId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final workTypes = app.workTypeRepo.getAll();
    _workTypeId ??= workTypes.isNotEmpty ? workTypes.first.id : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Text('New Task', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _workTypeId,
                  decoration: const InputDecoration(labelText: 'Work Type *'),
                  items: workTypes
                      .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _workTypeId = v),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _workDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _workDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Work Date *'),
                    child: Text(
                        '${_workDate.day.toString().padLeft(2, '0')}/${_workDate.month.toString().padLeft(2, '0')}/${_workDate.year}'),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _field,
                  decoration: const InputDecoration(labelText: 'Farm / Field *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Field is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(context, openAfter: false),
                        child: const Text('SAVE TASK'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : () => _save(context, openAfter: true),
                        child: const Text('SAVE & OPEN'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, {required bool openAfter}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_workTypeId == null) return;
    setState(() => _saving = true);
    final app = context.read<AppState>();
    final task = await app.createTask(
      title: _title.text,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      workTypeId: _workTypeId!,
      workDate: _workDate,
      field: _field.text,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!context.mounted) return;
    Navigator.pop(context);
    if (openAfter) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)));
    }
  }
}
