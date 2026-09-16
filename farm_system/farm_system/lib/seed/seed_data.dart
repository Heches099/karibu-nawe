import '../models/work_type.dart';
import '../models/user.dart';
import '../core/constants/enums.dart';
import '../state/app_state.dart';

/// Seeds realistic sample data (spec section 35) so the Boss Dashboard
/// is never empty on first run, and so every scenario in spec section 34
/// (partial payment, adjustment, multi-worker collector, handovers) is
/// already visible for a reviewer to click through.
class SeedData {
  static Future<void> run(AppState app) async {
    if (app.taskRepo.getAll().isNotEmpty) return; // already seeded

    for (final wt in WorkType.builtIns()) {
      await app.workTypeRepo.put(wt.id, wt);
    }
    await app.userRepo.put('u_boss', const AppUser(id: 'u_boss', name: 'Boss', role: UserRole.boss));

    final today = DateTime.now();

    // --- Task 1: Kupalilia Shamba la Mashariki (adjustment + partial + collector) ---
    final t1 = await app.createTask(
      title: 'Kupalilia Shamba la Mashariki',
      description: 'Kupalilia sehemu ya mashariki ya shamba.',
      workTypeId: 'wt_kupalilia',
      workDate: today,
      field: 'Mashariki',
    );
    await app.saveCalculation(
      taskId: t1.id,
      workTypeId: 'wt_kupalilia',
      category: CalculationCategory.areaFixedPayment,
      inputs: {'length': 30, 'width': 30, 'agreedPayment': 4000},
    );
    final aJuma = await app.addWorkerToTask(taskId: t1.id, workerName: 'Juma');
    final aMusa = await app.addWorkerToTask(
      taskId: t1.id,
      workerName: 'Musa',
      allocatedAmount: 4500,
      adjustmentReason: 'Musa completed an additional section.',
    );
    final aAli = await app.addWorkerToTask(taskId: t1.id, workerName: 'Ali');

    // Juma: fully paid.
    await app.paymentService.recordPayment(
        allocation: aJuma, amount: 4000, actor: app.currentUser, method: 'Cash');
    // Musa: fully paid (his adjusted amount).
    await app.paymentService.recordPayment(
        allocation: aMusa, amount: 4500, actor: app.currentUser, method: 'Mobile Money');
    // Ali: partially paid, and someone else collects the rest via a collector.
    await app.paymentService.recordPayment(
        allocation: aAli, amount: 2000, actor: app.currentUser, method: 'Cash');

    // --- Task 2: Kupiga Dawa Shamba B (spraying formula) ---
    final t2 = await app.createTask(
      title: 'Kupiga Dawa Shamba B',
      description: 'Kupiga dawa ya wadudu shamba B.',
      workTypeId: 'wt_kupiga_dawa',
      workDate: today,
      field: 'Shamba B',
    );
    await app.saveCalculation(
      taskId: t2.id,
      workTypeId: 'wt_kupiga_dawa',
      category: CalculationCategory.sprayingChemical,
      inputs: {
        'length': 30,
        'width': 30,
        'coveragePerLitre': 1000,
        'pricePerLitre': 8000,
        'applications': 1,
      },
    );
    final aAsha = await app.addWorkerToTask(taskId: t2.id, workerName: 'Asha');
    await app.paymentService.recordPayment(
        allocation: aAsha, amount: 7200, actor: app.currentUser, method: 'Cash');

    // --- Task 3: Kupanda Shamba C ---
    final t3 = await app.createTask(
      title: 'Kupanda Shamba C',
      description: 'Kupanda mbegu shamba C.',
      workTypeId: 'wt_kupanda',
      workDate: today.subtract(const Duration(days: 1)),
      field: 'Shamba C',
    );
    await app.saveCalculation(
      taskId: t3.id,
      workTypeId: 'wt_kupanda',
      category: CalculationCategory.areaFixedPayment,
      inputs: {'length': 40, 'width': 25, 'agreedPayment': 5000},
    );
    final aJohn = await app.addWorkerToTask(taskId: t3.id, workerName: 'John');

    // --- Task 4: Kuvuna Shamba D (quantity-based) ---
    final t4 = await app.createTask(
      title: 'Kuvuna Shamba D',
      description: 'Kuvuna mahindi shamba D.',
      workTypeId: 'wt_kuvuna',
      workDate: today.subtract(const Duration(days: 2)),
      field: 'Shamba D',
    );
    await app.saveCalculation(
      taskId: t4.id,
      workTypeId: 'wt_kuvuna',
      category: CalculationCategory.quantityWithRate,
      inputs: {'quantity': 120, 'pricePerUnit': 500, 'unit': 'kg'},
    );
    await app.addWorkerToTask(taskId: t4.id, workerName: 'Juma');

    // --- Musa collects for Ali, Asha, John: one collector, many workers ---
    // Ali already received TSh 2,000 directly; Musa collects the
    // remaining TSh 2,000 on Ali's behalf (Collection cannot exceed the
    // worker's outstanding balance).
    await app.collectionService.assignCollector(
      allocation: aAli,
      collectorWorkerId: aMusa.workerId,
      amount: app.paymentService.remaining(aAli),
      actor: app.currentUser,
      note: 'Ali is away from the farm today.',
    );
    final collectionForAsha = await app.collectionService.assignCollector(
      allocation: aAsha,
      collectorWorkerId: aMusa.workerId,
      amount: aAsha.allocatedAmount,
      actor: app.currentUser,
    );
    await app.collectionService.assignCollector(
      allocation: aJohn,
      collectorWorkerId: aMusa.workerId,
      amount: aJohn.allocatedAmount,
      actor: app.currentUser,
    );

    // Musa has handed over Asha's money already, but Ali's and John's are
    // still pending — demonstrates Collection != Handover clearly.
    await app.collectionService.completeHandover(
      collection: collectionForAsha,
      receivedBy: 'Asha',
      actor: app.currentUser,
    );
  }
}
