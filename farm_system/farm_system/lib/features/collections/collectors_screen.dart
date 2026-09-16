import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/currency_formatter.dart';
import '../../state/app_state.dart';
import '../workers/worker_detail_screen.dart';

/// Dedicated collector view (spec sections 15–16): lists every worker who
/// is currently collecting money for someone else, each with their total
/// collected and pending-handover figures, without mixing that money
/// with their own wages.
class CollectorsScreen extends StatelessWidget {
  const CollectorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final collectorIds = app.collectionRepo.getAll().map((c) => c.collectorWorkerId).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Collectors')),
      body: collectorIds.isEmpty
          ? Center(child: Text('No one is currently collecting for others.', style: TextStyle(color: Colors.grey[600])))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: collectorIds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final summary = app.collectorSummary(collectorIds[i]);
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => WorkerDetailScreen(workerId: collectorIds[i]))),
                    title: Text(app.workerName(collectorIds[i]), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Collecting for ${summary.lines.length} people · '
                        'Total ${CurrencyFormatter.format(summary.totalCollected)}',
                      ),
                    ),
                    trailing: summary.totalPending > 0
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Pending', style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                              Text(CurrencyFormatter.format(summary.totalPending),
                                  style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w700)),
                            ],
                          )
                        : const Icon(Icons.check_circle, color: Colors.green),
                  ),
                );
              },
            ),
    );
  }
}
