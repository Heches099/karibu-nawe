import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../models/payment.dart';
import '../../models/task.dart';
import '../../models/worker.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/forms.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/stat_card.dart';

class PaymentSheet extends StatefulWidget {
  final Task task;
  final Worker? worker;

  const PaymentSheet({super.key, required this.task, this.worker});

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Worker? _worker;
  Worker? _collector;
  DateTime _paidAt = DateTime.now();
  String _method = 'Cash';

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
  }

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
    final allocation = _worker == null
        ? null
        : store.allocationFor(taskId: widget.task.id, workerId: _worker!.id);
    final paid = _worker == null
        ? 0.0
        : store.totalPaidFor(taskId: widget.task.id, workerId: _worker!.id);
    final remaining = allocation == null ? 0.0 : allocation.allocatedAmount - paid;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<Worker>(
            value: _worker,
            onChanged: (v) => setState(() => _worker = v),
            decoration: const InputDecoration(labelText: 'Pay To', prefixIcon: Icon(Icons.person_outline)),
            items: [
              for (final w in allocatedWorkers)
                DropdownMenuItem(value: w, child: Text(w.name)),
            ],
          ),
          const SizedBox(height: 8),
          if (allocation != null)
            Row(
              children: [
                Expanded(child: InfoTile(
                  icon: Icons.gavel,
                  color: const Color(0xFF6A1B9A),
                  label: 'Allocated',
                  value: fmtMoney(allocation.allocatedAmount.round()),
                )),
                const SizedBox(width: 8),
                Expanded(child: InfoTile(
                  icon: Icons.trending_up,
                  color: const Color(0xFF2E7D32),
                  label: 'Paid',
                  value: fmtMoney(paid.round()),
                )),
                const SizedBox(width: 8),
                Expanded(child: InfoTile(
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFFEF6C00),
                  label: 'Remaining',
                  value: fmtMoney(remaining.round()),
                )),
              ],
            ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _amount,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: 'TSh ',
              hintText: remaining > 0 ? 'remaining ${remaining.round()}' : null,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [Formatters.nonNegativeDecimal],
            validator: (v) {
              final m = Validators.money(v);
              if (m != null) return m;
              final amt = Formatters.parseAmount(v!)!;
              if (amt > remaining + 0.001) {
                return 'Amount exceeds remaining balance of TSh ${remaining.round()}.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Paid On', prefixIcon: Icon(Icons.event)),
            child: InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _paidAt.isAfter(now) ? now : _paidAt,
                  firstDate: DateTime(now.year - 3),
                  lastDate: now,
                );
                if (d != null) setState(() => _paidAt = d);
              },
              child: Text(fmtDate(_paidAt)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _method,
            onChanged: (v) => setState(() => _method = v ?? 'Cash'),
            decoration: const InputDecoration(labelText: 'Payment Method', prefixIcon: Icon(Icons.payments_outlined)),
            items: const [
              DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
              DropdownMenuItem(value: 'Tigo Pesa', child: Text('Tigo Pesa')),
              DropdownMenuItem(value: 'Airtel Money', child: Text('Airtel Money')),
              DropdownMenuItem(value: 'Bank', child: Text('Bank')),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Worker?>(
            value: _collector,
            onChanged: (v) => setState(() => _collector = v),
            decoration: const InputDecoration(
              labelText: 'Collected By (optional)',
              prefixIcon: Icon(Icons.arrow_downward),
              helperText: 'Select a worker who collected this money on behalf of the payee.',
            ),
            items: [
              const DropdownMenuItem<Worker?>(value: null, child: Text('— Direct to worker —')),
              for (final w in store.workers.where((w) => w.isActive && w.id != _worker?.id))
                DropdownMenuItem<Worker?>(value: w, child: Text(w.name)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note (optional)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              try {
                final p = await store.addPayment(
                  task: widget.task,
                  worker: _worker!,
                  amount: Formatters.parseAmount(_amount.text)!,
                  paidAt: _paidAt,
                  method: _method,
                  note: _note.text,
                  collectedBy: _collector,
                );
                if (mounted) {
                  Navigator.pop(context);
                  showSuccess(
                    context,
                    _collector != null && _collector!.id != _worker!.id
                        ? 'TSh ${p.amount.round()} paid to ${_worker!.name} via ${_collector!.name}.'
                        : 'TSh ${p.amount.round()} paid to ${_worker!.name}.',
                  );
                }
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }
}

class PaymentHistorySheet extends StatelessWidget {
  final Task task;
  final Worker? worker;
  const PaymentHistorySheet({super.key, required this.task, this.worker});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final pays = store.paymentsFor(taskId: task.id, workerId: worker?.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pays.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No payments recorded yet.'),
          ),
        for (final p in pays) ...[
          _PaymentTile(payment: p),
          const SizedBox(height: 8),
        ],
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              MoneyText(pays.fold<double>(0, (s, p) => s + p.amount), style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Payment payment;
  const _PaymentTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    Collection? collection;
    for (final c in store.collections) {
      if (c.taskId == payment.taskId &&
          c.workerId == payment.workerId &&
          (c.amount - payment.amount).abs() < 0.001) {
        collection = c;
        break;
      }
    }
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
          child: const Icon(Icons.payments_outlined),
        ),
        title: Text('TSh ${fmtMoneyPlain(payment.amount.round())}'),
        subtitle: Text('${fmtDateTime(payment.paidAt)} · ${payment.method.isEmpty ? 'Cash' : payment.method}'
            '${payment.note != null && payment.note!.isNotEmpty ? '\n${payment.note}' : ''}'),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (collection != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_downward, size: 14, color: const Color(0xFF0277BD)),
                  Text('Collected by ${store.workerName(collection.collectorId)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF0277BD))),
                ],
              ),
            Text(store.workerName(payment.workerId), style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}