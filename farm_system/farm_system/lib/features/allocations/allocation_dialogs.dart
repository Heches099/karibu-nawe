import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../models/allocation.dart';
import '../../models/collection.dart';
import '../../state/app_state.dart';

/// All the small modal forms for the worker/allocation/payment/collection
/// actions live together here since they are short, related, and mostly
/// reused from both the Worksheet and the Worker Detail screen.

Future<void> showAddWorkerDialog(BuildContext context, String taskId) async {
  final app = context.read<AppState>();
  final calc = app.calculationRepo.activeForTask(taskId);
  if (calc == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save a calculation for this task first.')),
    );
    return;
  }

  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController(text: calc.expectedAmount.toString());
  final reasonCtrl = TextEditingController();
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final differs = int.tryParse(amountCtrl.text.trim()) != calc.expectedAmount;
      return AlertDialog(
        title: const Text('Add Worker'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Worker name *')),
              const SizedBox(height: 10),
              Text('Expected Amount: ${CurrencyFormatter.format(calc.expectedAmount)}',
                  style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Allocated Amount *'),
                onChanged: (_) => setState(() {}),
              ),
              if (differs) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason for difference *'),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await app.addWorkerToTask(
                  taskId: taskId,
                  workerName: nameCtrl.text,
                  allocatedAmount: int.tryParse(amountCtrl.text.trim()),
                  adjustmentReason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
              }
            },
            child: const Text('Add'),
          ),
        ],
      );
    }),
  );
}

Future<void> showAdjustAllocationDialog(BuildContext context, Allocation allocation) async {
  final app = context.read<AppState>();
  final amountCtrl = TextEditingController(text: allocation.allocatedAmount.toString());
  final reasonCtrl = TextEditingController();
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final newAmount = int.tryParse(amountCtrl.text.trim()) ?? allocation.allocatedAmount;
      final differsFromExpected = newAmount != allocation.expectedAmount;
      return AlertDialog(
        title: const Text('Adjust Allocation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Expected: ${CurrencyFormatter.format(allocation.expectedAmount)}'),
              Text('Current Allocated: ${CurrencyFormatter.format(allocation.allocatedAmount)}'),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New Allocated Amount *'),
                onChanged: (_) => setState(() {}),
              ),
              if (differsFromExpected) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason *'),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await app.paymentService.adjustAllocation(
                  allocation: allocation,
                  newAmount: newAmount,
                  reason: reasonCtrl.text,
                  actor: app.currentUser,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                setState(() => error = e.toString());
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    }),
  );
}

Future<void> showRecordPaymentDialog(BuildContext context, Allocation allocation) async {
  final app = context.read<AppState>();
  final remaining = app.paymentService.remaining(allocation);
  final amountCtrl = TextEditingController(text: remaining.toString());
  final noteCtrl = TextEditingController();
  String method = 'Cash';
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: const Text('Record Payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remaining: ${CurrencyFormatter.format(remaining)}'),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount *'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: ['Cash', 'Mobile Money', 'Bank']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => method = v ?? 'Cash'),
              ),
              const SizedBox(height: 10),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await app.paymentService.recordPayment(
                  allocation: allocation,
                  amount: int.tryParse(amountCtrl.text.trim()) ?? 0,
                  actor: app.currentUser,
                  method: method,
                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                setState(() => error = e.toString());
              }
            },
            child: const Text('Record Payment'),
          ),
        ],
      );
    }),
  );
}

Future<void> showAssignCollectorDialog(BuildContext context, Allocation allocation) async {
  final app = context.read<AppState>();
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController(text: allocation.allocatedAmount.toString());
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: const Text('Assign Collector'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Money owed to ${app.workerName(allocation.workerId)}: '
                  '${CurrencyFormatter.format(allocation.allocatedAmount)}'),
              const SizedBox(height: 10),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Collector name *')),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount collected *'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                final collector = await app.ensureWorker(nameCtrl.text);
                await app.collectionService.assignCollector(
                  allocation: allocation,
                  collectorWorkerId: collector.id,
                  amount: int.tryParse(amountCtrl.text.trim()) ?? 0,
                  actor: app.currentUser,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                setState(() => error = e.toString());
              }
            },
            child: const Text('Assign'),
          ),
        ],
      );
    }),
  );
}

/// Rule 9: recording a Handover is a distinct action from recording a
/// Collection, and can never exceed what is still held.
Future<void> showCompleteHandoverDialog(BuildContext context, Collection collection) async {
  final app = context.read<AppState>();
  final pending = app.collectionService.pendingHandoverFor(collection);
  final amountCtrl = TextEditingController(text: pending.toString());
  final receivedByCtrl = TextEditingController(text: app.workerName(collection.forWorkerId));
  String? error;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: const Text('Complete Handover'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Held by ${app.workerName(collection.collectorWorkerId)}: '
                  '${CurrencyFormatter.format(pending)} pending'),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount handed over *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: receivedByCtrl,
                decoration: const InputDecoration(labelText: 'Received by *'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await app.collectionService.completeHandover(
                  collection: collection,
                  receivedBy: receivedByCtrl.text,
                  actor: app.currentUser,
                  amount: int.tryParse(amountCtrl.text.trim()),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                setState(() => error = e.toString());
              }
            },
            child: const Text('Complete Handover'),
          ),
        ],
      );
    }),
  );
}
