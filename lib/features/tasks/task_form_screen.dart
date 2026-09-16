import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../models/work_type.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/forms.dart';
import 'task_detail_screen.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _field = TextEditingController();
  final _notes = TextEditingController();
  WorkType? _workType;
  DateTime _workDate = DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _field.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDate.isAfter(now) ? now : _workDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Work Date',
    );
    if (picked != null) setState(() => _workDate = picked);
  }

  Future<void> _save({required bool openAfter}) async {
    if (!_form.currentState!.validate()) return;
    final store = context.read<AppStore>();
    try {
      final task = store.createTask(
        title: _title.text,
        description: _description.text,
        workType: _workType!,
        workDate: _workDate,
        field: _field.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      if (openAfter) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: task.id),
        ));
      } else {
        showSuccess(context, 'Task saved.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final activeTypes = store.workTypes.where((w) => w.isActive).toList();
    if (_workType == null && activeTypes.isNotEmpty) {
      _workType = activeTypes.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Task'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _title,
                  validator: Validators.required,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Kupalilia Shamba la Mashariki',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WorkType>(
                  value: _workType,
                  onChanged: (v) => setState(() => _workType = v),
                  decoration: const InputDecoration(
                    labelText: 'Work Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final wt in activeTypes)
                      DropdownMenuItem(value: wt, child: Text(wt.name)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _field,
                  validator: Validators.required,
                  decoration: const InputDecoration(
                    labelText: 'Farm / Field',
                    hintText: 'e.g. Mashariki, Shamba A…',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Work Date',
                      prefixIcon: Icon(Icons.event),
                    ),
                    child: Text(fmtDate(_workDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    hintText: 'Describe the work that was done…',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _save(openAfter: false),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('SAVE TASK'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _save(openAfter: true),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('SAVE & OPEN'),
                      ),
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
}