import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/enums.dart';
import '../core/utils/id_generator.dart';
import '../models/allocation.dart';
import '../models/calculation.dart';
import '../models/collection.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../models/worker.dart';
import '../repositories/hive_boxes.dart';
import '../repositories/repositories.dart';
import '../services/audit/audit_service.dart';
import '../services/calculation/calculation_engine.dart';
import '../services/collection/collection_service.dart';
import '../services/payment/payment_service.dart';

/// The single orchestrator the UI talks to. It composes repositories +
/// services and exposes:
///  1) simple imperative methods for every user action in the spec, and
///  2) a [ChangeNotifier] that fires whenever ANY underlying Hive box
///     changes, which is what makes the Boss Dashboard feel "live" —
///     every screen listening via Provider rebuilds the moment a
///     payment/collection/allocation is written anywhere in the app,
///     including (with a real backend swapped in) from another device.
class AppState extends ChangeNotifier {
  AppState() {
    for (final name in HiveBoxes.all) {
      Hive.box(name).listenable().addListener(_onAnyChange);
    }
  }

  // Repositories
  final userRepo = UserRepository();
  final workerRepo = WorkerRepository();
  final workTypeRepo = WorkTypeRepository();
  final taskRepo = TaskRepository();
  final calculationRepo = CalculationRepository();
  final allocationRepo = AllocationRepository();
  final adjustmentRepo = AllocationAdjustmentRepository();
  final paymentRepo = PaymentRepository();
  final collectionRepo = CollectionRepository();
  final handoverRepo = HandoverRepository();
  final auditRepo = AuditLogRepository();

  // Services
  late final auditService = AuditService(auditRepo);
  late final paymentService = PaymentService(
    allocationRepo: allocationRepo,
    adjustmentRepo: adjustmentRepo,
    paymentRepo: paymentRepo,
    auditService: auditService,
  );
  late final collectionService = CollectionService(
    collectionRepo: collectionRepo,
    handoverRepo: handoverRepo,
    auditService: auditService,
    paymentService: paymentService,
  );

  // The signed-in actor. In a full deployment this comes from real auth;
  // kept simple here since the spec's focus is the financial workflow.
  AppUser currentUser = const AppUser(id: 'u_boss', name: 'Boss', role: UserRole.boss);

  bool get isOnline => true; // placeholder for real connectivity detection

  void _onAnyChange() => notifyListeners();

  // ---------------------------------------------------------------- TASKS
  Future<Task> createTask({
    required String title,
    String? description,
    required String workTypeId,
    required DateTime workDate,
    required String field,
    String? notes,
  }) async {
    final task = Task(
      id: IdGenerator.next(),
      title: title.trim(),
      description: description,
      workTypeId: workTypeId,
      workDate: workDate,
      field: field.trim(),
      notes: notes,
      createdBy: currentUser.id,
      createdAt: DateTime.now(),
    );
    await taskRepo.put(task.id, task);
    await auditService.log(
      action: AuditAction.taskCreated,
      actor: currentUser,
      taskId: task.id,
      description: 'Task created: ${task.title}',
    );
    return task;
  }

  // ---------------------------------------------------------- CALCULATION
  /// Saves a new Calculation as the task's baseline. If a calculation
  /// already exists for the task, the old one is marked superseded (kept
  /// forever) rather than overwritten — Rule 2 / Rule 11.
  Future<Calculation> saveCalculation({
    required String taskId,
    required String workTypeId,
    required CalculationCategory category,
    required Map<String, dynamic> inputs,
    String? revisionReason,
  }) async {
    final result = CalculationEngine.calculate(category: category, inputs: inputs);
    final previous = calculationRepo.activeForTask(taskId);

    final calculation = Calculation(
      id: IdGenerator.next(),
      taskId: taskId,
      workTypeId: workTypeId,
      inputs: result.inputs,
      measuredValue: result.measuredValue,
      measuredUnit: result.measuredUnit,
      expectedAmount: result.expectedAmount,
      supersedesCalculationId: previous?.id,
      revisionReason: previous != null ? revisionReason : null,
      createdBy: currentUser.id,
      createdAt: DateTime.now(),
    );
    await calculationRepo.put(calculation.id, calculation);

    if (previous != null) {
      await calculationRepo.put(previous.id, previous.markSuperseded(calculation.id));
    }

    await auditService.log(
      action: AuditAction.calculationSaved,
      actor: currentUser,
      taskId: taskId,
      oldValue: previous?.expectedAmount.toString(),
      newValue: calculation.expectedAmount.toString(),
      reason: revisionReason,
      description: previous == null
          ? 'Calculation saved — Expected Amount TSh ${calculation.expectedAmount}'
          : 'Calculation revised — TSh ${previous.expectedAmount} → TSh ${calculation.expectedAmount}',
    );

    return calculation;
  }

  // -------------------------------------------------------------- WORKERS
  Future<Worker> ensureWorker(String name, {String? phone}) async {
    final existing = workerRepo.getAll().where(
        (w) => w.name.trim().toLowerCase() == name.trim().toLowerCase());
    if (existing.isNotEmpty) return existing.first;

    final worker = Worker(
      id: IdGenerator.next(),
      name: name.trim(),
      phone: phone,
      createdAt: DateTime.now(),
    );
    await workerRepo.put(worker.id, worker);
    return worker;
  }

  Future<Allocation> addWorkerToTask({
    required String taskId,
    required String workerName,
    int? allocatedAmount,
    String? adjustmentReason,
  }) async {
    final calculation = calculationRepo.activeForTask(taskId);
    if (calculation == null) {
      throw StateError('Save a calculation for this task before adding workers.');
    }
    final worker = await ensureWorker(workerName);

    if (allocationRepo.forTaskAndWorker(taskId, worker.id) != null) {
      throw StateError('${worker.name} is already added to this task.');
    }

    final allocation = await paymentService.createAllocation(
      taskId: taskId,
      workerId: worker.id,
      calculation: calculation,
      actor: currentUser,
      initialAllocatedAmount: allocatedAmount,
      reasonIfDifferent: adjustmentReason,
    );

    await auditService.log(
      action: AuditAction.workerAdded,
      actor: currentUser,
      taskId: taskId,
      workerId: worker.id,
      description: '${worker.name} added to task',
    );

    return allocation;
  }

  // -------------------------------------------------------------- LOOKUPS
  Worker? worker(String id) => workerRepo.getById(id);
  Task? task(String id) => taskRepo.getById(id);
  Calculation? calculation(String id) => calculationRepo.getById(id);

  String workerName(String id) => worker(id)?.name ?? 'Unknown';
  String taskTitle(String id) => task(id)?.title ?? 'Unknown task';

  // ----------------------------------------------------------- DASHBOARD
  DashboardMetrics todayMetrics() => metricsFor(taskRepo
      .getAll()
      .where((t) => _isToday(t.workDate))
      .toList());

  DashboardMetrics metricsFor(List<Task> tasks) {
    final taskIds = tasks.map((t) => t.id).toSet();
    final allocations =
        allocationRepo.getAll().where((a) => taskIds.contains(a.taskId)).toList();
    final workerIds = allocations.map((a) => a.workerId).toSet();

    double totalArea = 0;
    for (final t in tasks) {
      final c = calculationRepo.activeForTask(t.id);
      if (c != null && c.measuredUnit == 'm²') totalArea += c.measuredValue;
    }

    var expected = 0, allocated = 0, paid = 0;
    for (final a in allocations) {
      expected += a.expectedAmount;
      allocated += a.allocatedAmount;
      paid += paymentService.totalPaid(a.id);
    }
    final remaining = allocated - paid;

    final relevantCollections =
        collectionRepo.getAll().where((c) => taskIds.contains(c.taskId)).toList();
    final collectedForOthers =
        relevantCollections.fold<int>(0, (sum, c) => sum + c.amount);
    final pendingHandover = relevantCollections.fold<int>(
        0, (sum, c) => sum + collectionService.pendingHandoverFor(c));

    final adjustedCount = allocations.where((a) => a.isAdjusted).length;
    final partialPayments = allocations
        .where((a) => paymentService.statusFor(a) == PaymentStatus.partial)
        .length;

    return DashboardMetrics(
      activeTasks: tasks.where((t) => t.status == TaskStatus.active).length,
      workerCount: workerIds.length,
      totalArea: totalArea,
      expected: expected,
      allocated: allocated,
      paid: paid,
      remaining: remaining,
      collectedForOthers: collectedForOthers,
      pendingHandover: pendingHandover,
      adjustedAllocations: adjustedCount,
      partialPayments: partialPayments,
      pendingHandoverCollections:
          relevantCollections.where((c) => collectionService.pendingHandoverFor(c) > 0).length,
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// Everything a collector is holding (Collected minus Handed Over) —
  /// kept strictly separate from the collector's own earnings (Rule 10).
  CollectorSummary collectorSummary(String collectorWorkerId) {
    final collections = collectionRepo.byCollector(collectorWorkerId);
    final lines = collections.map((c) {
      final pending = collectionService.pendingHandoverFor(c);
      return CollectorLine(
        collection: c,
        forWorkerName: workerName(c.forWorkerId),
        pendingAmount: pending,
        handedOverAmount: c.amount - pending,
      );
    }).toList();

    final totalCollected = lines.fold<int>(0, (s, l) => s + l.collection.amount);
    final totalPending = lines.fold<int>(0, (s, l) => s + l.pendingAmount);
    final totalHandedOver = lines.fold<int>(0, (s, l) => s + l.handedOverAmount);

    return CollectorSummary(
      collectorWorkerId: collectorWorkerId,
      lines: lines,
      totalCollected: totalCollected,
      totalPending: totalPending,
      totalHandedOver: totalHandedOver,
    );
  }
}

class DashboardMetrics {
  final int activeTasks;
  final int workerCount;
  final double totalArea;
  final int expected;
  final int allocated;
  final int paid;
  final int remaining;
  final int collectedForOthers;
  final int pendingHandover;
  final int adjustedAllocations;
  final int partialPayments;
  final int pendingHandoverCollections;

  const DashboardMetrics({
    required this.activeTasks,
    required this.workerCount,
    required this.totalArea,
    required this.expected,
    required this.allocated,
    required this.paid,
    required this.remaining,
    required this.collectedForOthers,
    required this.pendingHandover,
    required this.adjustedAllocations,
    required this.partialPayments,
    required this.pendingHandoverCollections,
  });
}

class CollectorLine {
  final Collection collection;
  final String forWorkerName;
  final int pendingAmount;
  final int handedOverAmount;
  const CollectorLine({
    required this.collection,
    required this.forWorkerName,
    required this.pendingAmount,
    required this.handedOverAmount,
  });
}

class CollectorSummary {
  final String collectorWorkerId;
  final List<CollectorLine> lines;
  final int totalCollected;
  final int totalPending;
  final int totalHandedOver;
  const CollectorSummary({
    required this.collectorWorkerId,
    required this.lines,
    required this.totalCollected,
    required this.totalPending,
    required this.totalHandedOver,
  });
}
