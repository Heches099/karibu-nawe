import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:farm_fms/core/errors/app_exception.dart';
import 'package:farm_fms/repositories/backend/app_backend.dart';
import 'package:farm_fms/services/store/app_store.dart';

void main() {
  late AppStore store;

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('store_rules_test.db');
    store = AppStore(AppBackend(db));
    await store.init();
    await store.login('boss', '1234');
    await store.seedDemoData(); // Explicit test fixture; production startup stays empty.
  });

  // ---- Auth
  group('Login', () {
    test('boss / 1234 succeeds', () async {
      await store.logout();
      final u = await store.login('boss', '1234');
      expect(u, isNotNull);
      expect(store.getCurrentUser()?.username, 'boss');
    });
    test('wrong password throws', () async {
      await store.logout();
      expect(() => store.login('boss', 'wrong'), throwsA(isA<ValidationException>()));
    });
  });

  // ---- Calculation
  group('Calculation baseline', () {
    test('saveCalculation succeeds on a fresh task', () async {
      final wt = store.workTypeById('wt_kupiga_dawa')!;
      final t = store.createTask(
        title: 'Fresh spraying task',
        description: 'Test task',
        workType: wt,
        workDate: DateTime.now(),
        field: 'Test field',
      );
      final calc = await store.saveCalculation(
        task: t,
        workType: wt,
        inputs: {'length': 30, 'width': 30, 'coverage': 1000, 'pricePerLitre': 8000, 'workerPayment': 4000},
      );
      expect(calc.expectedAmount, 4000);
    });
    test('second saveCalculation on same task throws', () async {
      final wt = store.workTypes.first;
      final t = store.tasks.firstWhere((tw) => tw.workTypeId == wt.id);
      store.allocations.removeWhere((a) => a.taskId == t.id);
      // first already seeded; run again to confirm duplication error
      expect(
        () => store.saveCalculation(
          task: t,
          workType: wt,
          inputs: {'length': 30, 'width': 30, 'agreedPayment': 4000},
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ---- Allocation rules
  group('Allocation rules', () {
    test('adding allocation with same expected and allocated needs no reason', () {
      final t = store.tasks.last;
      final freeWorker = store.workers.firstWhere(
        (w) => w.isActive && !store.allocationsFor(t.id).any((a) => a.workerId == w.id),
      );
      final calc = store.calculationFor(t.id);
      final alloc = store.addAllocation(
        task: t, worker: freeWorker,
        expectedAmount: calc?.expectedAmount ?? 4000,
        allocatedAmount: calc?.expectedAmount ?? 4000,
      );
      expect(alloc.allocatedAmount, alloc.expectedAmount);
    });
    test('adding allocation with different allocated amount requires reason', () {
      final t = store.tasks.last;
      final freeWorker = store.workers.firstWhere(
        (w) => w.isActive && !store.allocationsFor(t.id).any((a) => a.workerId == w.id),
      );
      expect(
        () => store.addAllocation(
          task: t, worker: freeWorker,
          expectedAmount: 4000, allocatedAmount: 3500,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
    test('adjustAllocation requires reason', () {
      final a = store.allocations.first;
      expect(
        () => store.adjustAllocation(allocationId: a.id, newAmount: a.allocatedAmount + 500, reason: ''),
        throwsA(isA<ValidationException>()),
      );
    });
    test('adjustAllocation with valid reason changes amount and records adjustment', () {
      final a = store.allocations.firstWhere((a) => (a.allocatedAmount - a.expectedAmount).abs() < 0.001);
      final orig = a.allocatedAmount;
      store.adjustAllocation(allocationId: a.id, newAmount: orig - 500, reason: 'Test adjustment');
      final updated = store.allocations.firstWhere((x) => x.id == a.id);
      expect(updated.allocatedAmount, orig - 500);
      expect(store.adjustmentsFor(a.id).first.reason, 'Test adjustment');
    });
    test('duplicate worker allocation throws', () {
      final a = store.allocations.first;
      final t = store.taskById(a.taskId)!;
      final w = store.workerById(a.workerId)!;
      expect(
        () => store.addAllocation(task: t, worker: w, expectedAmount: a.expectedAmount),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ---- Payment rules
  group('Payment rules', () {
    test('payment without allocation throws', () async {
      final t = store.tasks.first;
      final unallocated = store.workers.firstWhere(
        (w) => w.isActive && !store.allocationsFor(t.id).any((a) => a.workerId == w.id),
      );
      expect(
        () => store.addPayment(task: t, worker: unallocated, amount: 1000),
        throwsA(isA<ValidationException>()),
      );
    });
    test('overpayment throws', () async {
      final a = store.allocations.first;
      final t = store.taskById(a.taskId)!;
      final w = store.workerById(a.workerId)!;
      final paid = store.totalPaidFor(taskId: t.id, workerId: w.id);
      final remaining = a.allocatedAmount - paid;
      expect(
        () => store.addPayment(task: t, worker: w, amount: remaining + 1000),
        throwsA(isA<ValidationException>()),
      );
    });
    test('partial payment reduces remaining correctly', () async {
      final a = store.allocations.firstWhere((a) => a.allocatedAmount > 5000);
      final t = store.taskById(a.taskId)!;
      final w = store.workerById(a.workerId)!;
      final paidBefore = store.totalPaidFor(taskId: t.id, workerId: w.id);
      await store.addPayment(task: t, worker: w, amount: 1000, paidAt: DateTime(2025, 1, 2));
      expect(store.totalPaidFor(taskId: t.id, workerId: w.id), paidBefore + 1000);
    });
    test('collection creates payment + collection records', () async {
      final a = store.allocations.firstWhere((candidate) {
        final paid = store.totalPaidFor(taskId: candidate.taskId, workerId: candidate.workerId);
        return candidate.allocatedAmount - paid >= 1500;
      });
      final t = store.taskById(a.taskId)!;
      final worker = store.workerById(a.workerId)!;
      final collector = store.workers.firstWhere((w) => w.id != worker.id);
      final paidBefore = store.payments.length;
      final colsBefore = store.collections.length;
      await store.recordCollection(task: t, worker: worker, collector: collector, amount: 1500, collectedAt: DateTime(2025, 1, 3));
      expect(store.payments.length, paidBefore + 1);
      expect(store.collections.length, colsBefore + 1);
    });
    test('self-collection throws', () async {
      final a = store.allocations.first;
      final t = store.taskById(a.taskId)!;
      final w = store.workerById(a.workerId)!;
      expect(
        () => store.recordCollection(task: t, worker: w, collector: w, amount: 1000),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // ---- Handover rules
  group('Handover rules', () {
    test('handover exceeding pending throws', () async {
      final collector = store.workers.firstWhere((w) =>
        store.collections.any((c) => c.collectorId == w.id));
      final receivedBy = store.collections.firstWhere((c) => c.collectorId == collector.id).workerId;
      final pending = store.pendingHandoverForWorker(collectorId: collector.id, workerId: receivedBy);
      expect(pending, greaterThan(0));
      expect(
        () => store.addHandover(collector: collector, receivedBy: store.workerById(receivedBy)!, amount: pending + 1000),
        throwsA(isA<ValidationException>()),
      );
    });
    test('valid handover reduces pending', () async {
      final collector = store.workers.firstWhere((w) =>
        store.collections.any((c) => c.collectorId == w.id));
      final receivedBy = store.collections.firstWhere((c) => c.collectorId == collector.id).workerId;
      final pendingBefore = store.pendingHandoverForWorker(collectorId: collector.id, workerId: receivedBy);
      await store.addHandover(collector: collector, receivedBy: store.workerById(receivedBy)!, amount: pendingBefore);
      expect(store.pendingHandoverForWorker(collectorId: collector.id, workerId: receivedBy), closeTo(0, 0.01));
    });
  });

  // ---- Task deletion guard
  group('Task deletion', () {
    test('task with allocations cannot be deleted', () {
      final t = store.tasks.first;
      expect(
        () => store.deleteTask(t.id),
        throwsA(isA<ValidationException>()),
      );
    });
    test('task without allocations can be deleted', () async {
      final t = store.createTask(
        title: 'Temp Task', description: '', workType: store.workTypes.first,
        workDate: DateTime.now(), field: 'Test',
      );
      store.deleteTask(t.id);
      expect(store.taskById(t.id), isNull);
    });
  });

  // ---- Seed data correctness
  group('Seed data totals', () {
    test('Musa collected 226,000 across all tasks', () {
      final musa = store.workers.firstWhere((w) => w.name == 'Musa');
      final total = store.collections
          .where((c) => c.collectorId == musa.id)
          .fold<double>(0, (s, c) => s + c.amount);
      expect(total, 226000);
    });
    test('one handover of 120,000 from Musa to Ali exists', () {
      final musa = store.workers.firstWhere((w) => w.name == 'Musa');
      final ali = store.workers.firstWhere((w) => w.name == 'Ali');
      final pending = store.pendingHandoverForWorker(collectorId: musa.id, workerId: ali.id);
      // ali collected 200000 + musa collected 4500 for ali? Actually musa collected for ali only 200000 in t1
      expect(pending, closeTo(82000, 1)); // 202,000 collected - 120,000 handed = 82,000
    });
  });
}
