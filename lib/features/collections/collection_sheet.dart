import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../models/task.dart';
import '../../models/worker.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/forms.dart';
import '../../shared/widgets/stat_card.dart';

/// A collector receives money that belongs to another worker.
class CollectionSheet extends StatefulWidget {
  final Task task;
  const CollectionSheet({super.key, required this.task});

  @override
  State<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends State<CollectionSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Worker? _worker;
  Worker? _collector;
  DateTime _when = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final allocs = store.allocationsFor(widget.task.id);
    final allocatedWorkers = allocs.map((a) => store.workerById(a.workerId)).whereType<Worker>().toList();
    if (_worker == null && allocatedWorkers.isNotEmpty) {
      _worker = allocatedWorkers.first;
    }
    final collectors = store.workers.where((w) => w.isActive && w.id != _worker?.id).toList();
    if (_collector == null && collectors.isNotEmpty) _collector = collectors.first;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<Worker>(
            value: _worker,
            onChanged: (v) => setState(() => _worker = v),
            decoration: const InputDecoration(labelText: 'Money Belongs To (Worker)', prefixIcon: Icon(Icons.person_outline)),
            items: [for (final w in allocatedWorkers) DropdownMenuItem(value: w, child: Text(w.name))],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Worker>(
            value: _collector,
            onChanged: (v) => setState(() => _collector = v),
            decoration: const InputDecoration(
              labelText: 'Collector (Who Takes The Money)',
              prefixIcon: Icon(Icons.arrow_downward),
            ),
            items: [
              for (final w in collectors.where((w) => w.id != _worker?.id))
                DropdownMenuItem(value: w, child: Text(w.name)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            decoration: const InputDecoration(labelText: 'Amount', prefixText: 'TSh '),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [Formatters.nonNegativeDecimal],
            validator: Validators.money,
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event)),
            child: InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 3), lastDate: now);
                if (d != null) setState(() => _when = d);
              },
              child: Text(fmtDate(_when)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)', alignLabelWithHint: true)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              try {
                await store.recordCollection(
                  task: widget.task,
                  worker: _worker!,
                  collector: _collector!,
                  amount: Formatters.parseAmount(_amount.text)!,
                  collectedAt: _when,
                  note: _note.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  showSuccess(context, '${_collector!.name} now holds TSh ${Formatters.parseAmount(_amount.text)!.round()} for ${_worker!.name}.');
                }
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Record Collection'),
          ),
        ],
      ),
    );
  }
}

/// Handover: collector physically gives money to the original worker.
class HandoverSheet extends StatefulWidget {
  final Worker collector;

  const HandoverSheet({super.key, required this.collector});

  @override
  State<HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends State<HandoverSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Worker? _receiver;
  DateTime _when = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final receivers = store.collectionsByCollector(widget.collector.id).map((c) => store.workerById(c.workerId)).whereType<Worker>().toSet().toList();
    if (_receiver == null && receivers.isNotEmpty) _receiver = receivers.first;

    final pending = _receiver == null ? 0.0 : store.pendingHandoverForWorker(collectorId: widget.collector.id, workerId: _receiver!.id);
    final globalPending = store.pendingHandoverBy(widget.collector.id);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (receivers.isEmpty) ...[
            const Text('This collector has no outstanding collections for this task.'),
          ],
          DropdownButtonFormField<Worker>(
            value: _receiver,
            onChanged: (v) => setState(() => _receiver = v),
            decoration: const InputDecoration(labelText: 'Money Received By (Original Worker)'),
            items: [for (final w in receivers) DropdownMenuItem(value: w, child: Text(w.name))],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: InfoTile(icon: Icons.schedule, color: const Color(0xFFEF6C00), label: 'Pending for this worker', value: fmtMoney(pending.round()))),
              const SizedBox(width: 8),
              Expanded(child: InfoTile(icon: Icons.hourglass_empty, color: const Color(0xFF0277BD), label: "Collector's total pending", value: fmtMoney(globalPending.round()))),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            decoration: InputDecoration(labelText: 'Handover Amount', prefixText: 'TSh ', hintText: pending.round() == 0 ? null : 'up to ${pending.round()}'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [Formatters.nonNegativeDecimal],
            validator: (v) {
              final m = Validators.money(v);
              if (m != null) return m;
              final amt = Formatters.parseAmount(v!)!;
              if (amt > pending + 0.001) return 'Cannot exceed TSh ${pending.round()} pending for this worker.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event)),
            child: InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 3), lastDate: now);
                if (d != null) setState(() => _when = d);
              },
              child: Text(fmtDate(_when)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)', alignLabelWithHint: true)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              try {
                final h = await store.addHandover(
                  collector: widget.collector,
                  receivedBy: _receiver!,
                  amount: Formatters.parseAmount(_amount.text)!,
                  handedAt: _when,
                  note: _note.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  showSuccess(context, 'Handover of TSh ${h.amount.round()} to ${_receiver!.name} completed.');
                }
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Confirm Handover'),
          ),
        ],
      ),
    );
  }
}