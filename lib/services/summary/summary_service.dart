import '../../core/utils/format.dart';
import '../../models/allocation.dart';
import '../../models/calculation.dart';
import '../../models/payment.dart';
import '../../models/task.dart';
import '../../models/enums.dart';

/// Per-task money/area summary, computed from the raw entity lists.
class TaskSummary {
  final String taskId;
  final double area;
  final double expected;
  final double allocated;
  final double adjustmentTotal;
  final double paid;
  final double remaining;
  final double collectedForOthers;
  final double pendingHandover;
  final int workerCount;

  const TaskSummary({
    required this.taskId,
    this.area = 0,
    this.expected = 0,
    this.allocated = 0,
    this.adjustmentTotal = 0,
    this.paid = 0,
    this.remaining = 0,
    this.collectedForOthers = 0,
    this.pendingHandover = 0,
    this.workerCount = 0,
  });
}

/// A single worker's money position.
class WorkerMoney {
  final String workerId;
  final double expected;
  final double allocated;
  final double adjustment;
  final double paid;
  final double remaining;
  final PaymentStatus paymentStatus;
  final double collectedForOthers; // money they hold for others
  final double handedOver;
  final double pendingHandover;
  final int collectionCount;
  final int handoverCount;

  const WorkerMoney({
    required this.workerId,
    this.expected = 0,
    this.allocated = 0,
    this.adjustment = 0,
    this.paid = 0,
    this.remaining = 0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.collectedForOthers = 0,
    this.handedOver = 0,
    this.pendingHandover = 0,
    this.collectionCount = 0,
    this.handoverCount = 0,
  });
}

/// Everything the Boss sees at a glance on a given date period.
class DashboardStats {
  final int activeTasks;
  final int totalWorkers;
  final int workersWithAllocations;
  final double totalArea;
  final double expected;
  final double allocated;
  final double adjustmentTotal;
  final double paid;
  final double remaining;
  final double collectedForOthers;
  final double handedOver;
  final double pendingHandover;
  final int partialPayments;
  final int adjustedAllocations;
  final int unpaidAllocations;

  const DashboardStats({
    this.activeTasks = 0,
    this.totalWorkers = 0,
    this.workersWithAllocations = 0,
    this.totalArea = 0,
    this.expected = 0,
    this.allocated = 0,
    this.adjustmentTotal = 0,
    this.paid = 0,
    this.remaining = 0,
    this.collectedForOthers = 0,
    this.handedOver = 0,
    this.pendingHandover = 0,
    this.partialPayments = 0,
    this.adjustedAllocations = 0,
    this.unpaidAllocations = 0,
  });
}

class SummaryService {
  const SummaryService();

  /// Builds a per-task summary. [taskId] null means "all tasks".
  TaskSummary summarizeTask({
    required String taskId,
    required List<Calculation> calculations,
    required List<Allocation> allocations,
    required List<Payment> payments,
    required List<Collection> collections,
    required List<Handover> handovers,
  }) {
    double area = 0, expected = 0, allocated = 0, adjustment = 0, paid = 0;
    final taskPayments = payments.where((p) => p.taskId == taskId);
    final taskCalcs = calculations.where((c) => c.taskId == taskId);
    final taskAllocs = allocations.where((a) => a.taskId == taskId);
    final taskCols = collections.where((c) => c.taskId == taskId);

    for (final c in taskCalcs) {
      area += (c.outputs['area'] as num?)?.toDouble() ?? 0;
      expected += c.expectedAmount;
    }
    for (final a in taskAllocs) {
      allocated += a.allocatedAmount;
      adjustment += (a.allocatedAmount - a.expectedAmount);
    }
    for (final p in taskPayments) {
      paid += p.amount;
    }
    var collected = 0.0;
    for (final c in taskCols) {
      collected += c.amount;
    }
    var handed = 0.0;
    for (final h in handovers) {
      if (h.taskId == taskId) handed += h.amount;
    }
    return TaskSummary(
      taskId: taskId,
      area: area,
      expected: expected,
      allocated: allocated,
      adjustmentTotal: adjustment,
      paid: paid,
      remaining: allocated - paid,
      collectedForOthers: collected,
      pendingHandover: collected - handed,
      workerCount: taskAllocs.length,
    );
  }

  /// Money position of one worker across all tasks.
  WorkerMoney workerMoney({
    required String workerId,
    List<Allocation> allocations = const [],
    List<Payment> payments = const [],
    List<Collection> collections = const [],
    List<Handover> handovers = const [],
  }) {
    var expected = 0.0, allocated = 0.0, paid = 0.0;
    for (final a in allocations.where((x) => x.workerId == workerId)) {
      expected += a.expectedAmount;
      allocated += a.allocatedAmount;
    }
    for (final p in payments.where((x) => x.workerId == workerId)) {
      paid += p.amount;
    }
    var collected = 0.0;
    var nCol = 0;
    for (final c in collections.where((x) => x.collectorId == workerId)) {
      collected += c.amount;
      nCol++;
    }
    var handed = 0.0;
    var nHan = 0;
    for (final h in handovers.where((x) => x.collectorId == workerId)) {
      handed += h.amount;
      nHan++;
    }
    return WorkerMoney(
      workerId: workerId,
      expected: expected,
      allocated: allocated,
      adjustment: allocated - expected,
      paid: paid,
      remaining: allocated - paid,
      paymentStatus: allocateCountEqual(allocated, paid) ? PaymentStatus.paid : derivePaymentStatus(allocated, paid),
      collectedForOthers: collected,
      handedOver: handed,
      pendingHandover: collected - handed,
      collectionCount: nCol,
      handoverCount: nHan,
    );
  }

  bool allocateCountEqual(num a, num b) => (a - b).abs() < 0.001;

  /// Boss dashboard for the given date period (inclusive range).
  DashboardStats dashboard({
    required List<Task> tasks,
    required List<Calculation> calculations,
    required List<Allocation> allocations,
    required List<Payment> payments,
    required List<Collection> collections,
    required List<Handover> handovers,
    required int totalWorkers,
    DateTime? from,
    DateTime? to,
  }) {
    final periodTasks = tasks.where((t) {
      final f = from;
      final to2 = to;
      if (f == null || to2 == null) return true;
      return inRange(t.workDate, f, to2);
    }).toList();
    final ids = periodTasks.map((t) => t.id).toSet();

    final calcs = calculations.where((c) => ids.contains(c.taskId)).toList();
    final allocs = allocations.where((a) => ids.contains(a.taskId)).toList();
    final pays = payments.where((p) => ids.contains(p.taskId)).toList();
    final cols = collections.where((c) => ids.contains(c.taskId)).toList();
    final handed = handovers.where((h) => ids.contains(h.taskId)).toList();

    double area = 0, expected = 0, allocated = 0, adj = 0, paid = 0;
    for (final c in calcs) {
      area += (c.outputs['area'] as num?)?.toDouble() ?? 0;
      expected += c.expectedAmount;
    }
    for (final a in allocs) {
      allocated += a.allocatedAmount;
      adj += a.allocatedAmount - a.expectedAmount;
    }
    for (final p in pays) {
      paid += p.amount;
    }
    var collected = 0.0;
    for (final c in cols) {
      collected += c.amount;
    }
    var handedOver = 0.0;
    for (final h in handed) {
      handedOver += h.amount;
    }

    var partial = 0, adjusted = 0, unpaid = 0;
    for (final a in allocs) {
      if ((a.allocatedAmount - a.expectedAmount).abs() > 0.001) adjusted++;
      var taskPaid = 0.0;
      for (final p in pays) {
        if (p.workerId == a.workerId && p.taskId == a.taskId) taskPaid += p.amount;
      }
      final st = derivePaymentStatus(a.allocatedAmount, taskPaid);
      if (st == PaymentStatus.partial) partial++;
      if (st == PaymentStatus.unpaid) unpaid++;
    }

    final workerIds = allocs.map((a) => a.workerId).toSet();

    return DashboardStats(
      activeTasks: periodTasks.where((t) => t.status == TaskStatus.active).length,
      totalWorkers: totalWorkers,
      workersWithAllocations: workerIds.length,
      totalArea: area,
      expected: expected,
      allocated: allocated,
      adjustmentTotal: adj,
      paid: paid,
      remaining: allocated - paid,
      collectedForOthers: collected,
      handedOver: handedOver,
      pendingHandover: collected - handedOver,
      partialPayments: partial,
      adjustedAllocations: adjusted,
      unpaidAllocations: unpaid,
    );
  }
}