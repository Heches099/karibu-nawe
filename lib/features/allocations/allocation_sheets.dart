import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/forms.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/empty_state.dart';

/// Assign a worker to a task with expected + (optional) adjusted allocated.
class AssignWorkerSheet extends StatefulWidget {
  final Task task;
  const AssignWorkerSheet({super.key, required this.task});

  @override
  State<AssignWorkerSheet> createState() => _AssignWorkerSheetState();
}

class _AssignWorkerSheetState extends State<AssignWorkerSheet> {
  final _form = GlobalKey<FormState>();
  final _allocated = TextEditingController();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  Worker? _worker;
  double? _expected;
  String? _reasonError;

  @override
  void dispose() {
    _allocated.dispose();
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<Worker> _available(AppStore store) {
    final assigned = store.allocationsFor(widget.task.id).map((a) => a.workerId).toSet();
    return store.workers.where((w) => w.isActive && !assigned.contains(w.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final calc = store.calculationFor(widget.task.id);
    final available = _available(store);
    if (_expected == null && calc != null) {
      _expected = calc.expectedAmount;
      if (_allocated.text.isEmpty) _allocated.text = '${_expected!.round()}';
    }

    double? allocatedVal() => Formatters.parseAmount(_allocated.text);
    final expectedVal = _expected;
    final allocatedVal2 = allocatedVal();
    final differs = expectedVal != null && allocatedVal2 != null && (allocatedVal2 - expectedVal).abs() > 0.001;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<Worker>(
            initialValue: _worker,
            onChanged: (v) => setState(() => _worker = v),
            decoration: const InputDecoration(labelText: 'Worker', prefixIcon: Icon(Icons.person_outline)),
            hint: const Text('Select a worker for this row'),
            validator: (value) => value == null ? 'Select a worker.' : null,
            items: [for (final w in available) DropdownMenuItem(value: w, child: Text(w.name))],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final worker = await showAppSheet<Worker>(
                  context,
                  const _QuickAddWorkerForm(),
                  title: 'Add Worker',
                );
                if (worker != null && mounted) setState(() => _worker = worker);
              },
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Add a new worker manually'),
            ),
          ),
          if (available.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('No more available workers, all active workers are already assigned.'),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _allocated,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [Formatters.nonNegativeDecimal],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Allocated Amount',
              prefixText: 'TSh ',
              hintText: expectedVal == null ? '0' : '${expectedVal.round()}',
            ),
            validator: Validators.money,
          ),
          if (expectedVal != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Text('Expected baseline: ', style: TextStyle(fontSize: 12)),
                  MoneyText(expectedVal, compact: true, style: const TextStyle(fontSize: 12)),
                  if (differs) ...[
                    const SizedBox(width: 8),
                    MoneyText(allocatedVal2 - expectedVal, showSign: true, compact: true, style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (differs) ...[
            TextField(
              controller: _reason,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'REASON REQUIRED — amount differs from expected',
                alignLabelWithHint: true,
                errorText: _reasonError,
                hintText: 'e.g. Completed an additional section.',
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              setState(() => _reasonError = null);
              if (!_form.currentState!.validate()) return;
              final alloc = Formatters.parseAmount(_allocated.text)!;
              final reasonText = _reason.text.trim();
              final needReason = expectedVal != null && (alloc - expectedVal).abs() > 0.001;
              if (needReason && reasonText.isEmpty) {
                setState(() => _reasonError = 'A reason is required when the amount differs from expected.');
                return;
              }
              try {
                final worker = _worker;
                if (worker == null) return;
                store.addAllocation(
                  task: widget.task,
                  worker: worker,
                  expectedAmount: expectedVal ?? alloc,
                  allocatedAmount: alloc,
                  reason: needReason ? reasonText : null,
                  notes: _notes.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  showSuccess(context, '${worker.name} assigned.');
                }
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Assign Worker'),
          ),
        ],
      ),
    );
  }
}

class _QuickAddWorkerForm extends StatefulWidget {
  const _QuickAddWorkerForm();

  @override
  State<_QuickAddWorkerForm> createState() => _QuickAddWorkerFormState();
}

class _QuickAddWorkerFormState extends State<_QuickAddWorkerForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _field = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            validator: Validators.required,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _field,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Usual Field (optional)', prefixIcon: Icon(Icons.place_outlined)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              final worker = context.read<AppStore>().addWorker(
                    name: _name.text,
                    phone: _phone.text,
                    field: _field.text,
                  );
              Navigator.pop(context, worker);
            },
            icon: const Icon(Icons.check),
            label: const Text('Add and Assign Worker'),
          ),
        ],
      ),
    );
  }
}

/// Change an allocation amount. A reason is always required.
class AdjustAllocationSheet extends StatefulWidget {
  final Allocation allocation;
  const AdjustAllocationSheet({super.key, required this.allocation});

  @override
  State<AdjustAllocationSheet> createState() => _AdjustAllocationSheetState();
}

class _AdjustAllocationSheetState extends State<AdjustAllocationSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount.text = '${widget.allocation.allocatedAmount.round()}';
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final current = widget.allocation.allocatedAmount;
    final newVal = Formatters.parseAmount(_amount.text);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current allocation'),
              MoneyText(current, compact: true),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expected baseline (never changes)'),
              MoneyText(widget.allocation.expectedAmount, compact: true, zeroColor: Theme.of(context).colorScheme.onSurface),
            ],
          ),
          if (newVal != null && (newVal - current).abs() > 0.001)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Difference'),
                MoneyText(newVal - current, showSign: true, compact: true),
              ],
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amount,
            decoration: const InputDecoration(labelText: 'New Allocated Amount', prefixText: 'TSh '),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [Formatters.nonNegativeDecimal],
            validator: Validators.money,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reason,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reason (required for every change)',
              alignLabelWithHint: true,
            ),
            validator: Validators.required,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              try {
                store.adjustAllocation(
                  allocationId: widget.allocation.id,
                  newAmount: Formatters.parseAmount(_amount.text)!,
                  reason: _reason.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  showSuccess(context, 'Allocation updated. Change recorded in history.');
                }
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Save Change'),
          ),
        ],
      ),
    );
  }
}

/// Full allocation + adjustment history for one worker task relation.
class AllocationHistorySheet extends StatelessWidget {
  final Allocation allocation;
  const AllocationHistorySheet({super.key, required this.allocation});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final history = store.adjustmentsFor(allocation.id);
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              InfoTile(
                icon: Icons.rule,
                color: const Color(0xFF2E7D32),
                label: 'Expected (baseline)',
                value: fmtMoney(allocation.expectedAmount.round()),
              ),
              const SizedBox(height: 8),
              InfoTile(
                icon: Icons.payments_outlined,
                color: const Color(0xFF6A1B9A),
                label: 'Current Allocated',
                value: fmtMoney(allocation.allocatedAmount.round()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...history.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TSh ${fmtMoneyPlain(h.fromAmount.round())} → TSh ${fmtMoneyPlain(h.toAmount.round())}',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          MoneyText(h.difference, showSign: true, compact: true),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(h.reason.isEmpty ? '—' : h.reason),
                      const SizedBox(height: 4),
                      Text('${fmtDateTime(h.createdAt)} · by ${h.changedBy}',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
            )),
        if (history.isEmpty) const Text('No changes so far.'),
      ],
    );
  }
}