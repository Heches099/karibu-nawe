import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../models/worker.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/forms.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/status_badge.dart';
import 'worker_detail_screen.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final q = _query.trim().toLowerCase();
    final visible = store.workers.where((w) {
      if (q.isEmpty) return true;
      return w.name.toLowerCase().contains(q) ||
          w.phone.toLowerCase().contains(q) ||
          (w.field?.toLowerCase().contains(q) ?? false);
    }).toList();

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
                        child: Text('Workers',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      ),
                      FilledButton.icon(
                        onPressed: () => _addWorker(context),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Add Worker'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search workers…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: store.workers.isEmpty
                  ? const EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No workers yet',
                      message: 'Add the people who work on the farm.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: visible.length,
                      itemBuilder: (ctx, i) => _WorkerCard(worker: visible[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addWorker(BuildContext context) {
    showAppSheet(
      context,
      const _AddWorkerForm(),
      title: 'Add Worker',
    );
  }
}

class _AddWorkerForm extends StatefulWidget {
  const _AddWorkerForm();

  @override
  State<_AddWorkerForm> createState() => _AddWorkerFormState();
}

class _AddWorkerFormState extends State<_AddWorkerForm> {
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
          TextFormField(controller: _name, validator: Validators.required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone))),
          const SizedBox(height: 12),
          TextFormField(controller: _field, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Usual Field (optional)', prefixIcon: Icon(Icons.place_outlined))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              context.read<AppStore>().addWorker(name: _name.text, phone: _phone.text, field: _field.text);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: const Text('Save Worker'),
          ),
        ],
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final Worker worker;
  const _WorkerCard({required this.worker});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final money = store.summary.workerMoney(
      workerId: worker.id,
      allocations: store.allocations,
      payments: store.payments,
      collections: store.collections,
      handovers: store.handovers,
    );
    final hasAllocation = money.allocated > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WorkerDetailScreen(workerId: worker.id),
          )),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(worker.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        worker.phone.isEmpty ? 'No phone' : worker.phone,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (money.pendingHandover > 0)
                      const StatusBadge(BadgeKind.pending, label: 'Holding'),
                    if (money.collectedForOthers > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_downward, size: 13, color: Color(0xFF0277BD)),
                          MoneyText(money.collectedForOthers, compact: true, bold: false, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(hasAllocation ? 'OWN EARNINGS' : 'Earnings', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      MoneyText(money.remaining < 0 ? 0 : money.remaining, compact: true, style: const TextStyle(fontSize: 13)),
                      Text(
                        hasAllocation ? 'of ${fmtMoneyPlain(money.allocated.round())}' : '—',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}