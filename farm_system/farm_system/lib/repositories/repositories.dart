import 'package:hive_flutter/hive_flutter.dart';

import '../models/user.dart';
import '../models/worker.dart';
import '../models/work_type.dart';
import '../models/task.dart';
import '../models/calculation.dart';
import '../models/allocation.dart';
import '../models/payment.dart';
import '../models/collection.dart';
import '../models/handover.dart';
import '../models/audit_log.dart';
import 'base_repository.dart';
import 'hive_boxes.dart';

/// One repository per aggregate, per the data model in spec section 27.
/// Each is a thin, explicit wrapper so it's obvious in code review exactly
/// what persistence guarantees exist for each entity.

class UserRepository extends BaseRepository<AppUser> {
  UserRepository()
      : super(
          Hive.box(HiveBoxes.users),
          toMap: (u) => u.toMap(),
          fromMap: (m) => AppUser.fromMap(m),
        );
}

class WorkerRepository extends BaseRepository<Worker> {
  WorkerRepository()
      : super(
          Hive.box(HiveBoxes.workers),
          toMap: (w) => w.toMap(),
          fromMap: (m) => Worker.fromMap(m),
        );
}

class WorkTypeRepository extends BaseRepository<WorkType> {
  WorkTypeRepository()
      : super(
          Hive.box(HiveBoxes.workTypes),
          toMap: (w) => w.toMap(),
          fromMap: (m) => WorkType.fromMap(m),
        );
}

class TaskRepository extends BaseRepository<Task> {
  TaskRepository()
      : super(
          Hive.box(HiveBoxes.tasks),
          toMap: (t) => t.toMap(),
          fromMap: (m) => Task.fromMap(m),
        );
}

class CalculationRepository extends BaseRepository<Calculation> {
  CalculationRepository()
      : super(
          Hive.box(HiveBoxes.calculations),
          toMap: (c) => c.toMap(),
          fromMap: (m) => Calculation.fromMap(m),
        );

  List<Calculation> forTask(String taskId) =>
      getAll().where((c) => c.taskId == taskId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// The currently-active (non-superseded) calculation for a task, i.e.
  /// the one whose expectedAmount is the live baseline.
  Calculation? activeForTask(String taskId) {
    final list = forTask(taskId).where((c) => !c.isSuperseded);
    return list.isEmpty ? null : list.last;
  }
}

class AllocationRepository extends BaseRepository<Allocation> {
  AllocationRepository()
      : super(
          Hive.box(HiveBoxes.allocations),
          toMap: (a) => a.toMap(),
          fromMap: (m) => Allocation.fromMap(m),
        );

  List<Allocation> forTask(String taskId) =>
      getAll().where((a) => a.taskId == taskId).toList();

  List<Allocation> forWorker(String workerId) =>
      getAll().where((a) => a.workerId == workerId).toList();

  Allocation? forTaskAndWorker(String taskId, String workerId) {
    final matches =
        getAll().where((a) => a.taskId == taskId && a.workerId == workerId);
    return matches.isEmpty ? null : matches.first;
  }
}

class AllocationAdjustmentRepository extends BaseRepository<AllocationAdjustment> {
  AllocationAdjustmentRepository()
      : super(
          Hive.box(HiveBoxes.adjustments),
          toMap: (a) => a.toMap(),
          fromMap: (m) => AllocationAdjustment.fromMap(m),
        );

  List<AllocationAdjustment> forAllocation(String allocationId) =>
      getAll().where((a) => a.allocationId == allocationId).toList()
        ..sort((a, b) => a.changedAt.compareTo(b.changedAt));
}

class PaymentRepository extends BaseRepository<Payment> {
  PaymentRepository()
      : super(
          Hive.box(HiveBoxes.payments),
          toMap: (p) => p.toMap(),
          fromMap: (m) => Payment.fromMap(m),
        );

  List<Payment> forAllocation(String allocationId) =>
      getAll().where((p) => p.allocationId == allocationId).toList()
        ..sort((a, b) => a.paidAt.compareTo(b.paidAt));

  int totalPaidForAllocation(String allocationId) =>
      forAllocation(allocationId).fold(0, (sum, p) => sum + p.amount);

  List<Payment> forTask(String taskId) =>
      getAll().where((p) => p.taskId == taskId).toList();
}

class CollectionRepository extends BaseRepository<Collection> {
  CollectionRepository()
      : super(
          Hive.box(HiveBoxes.collections),
          toMap: (c) => c.toMap(),
          fromMap: (m) => Collection.fromMap(m),
        );

  List<Collection> byCollector(String collectorWorkerId) => getAll()
      .where((c) => c.collectorWorkerId == collectorWorkerId)
      .toList();

  List<Collection> forAllocation(String allocationId) =>
      getAll().where((c) => c.allocationId == allocationId).toList();

  Collection? forWorkerOnTask(String taskId, String forWorkerId) {
    final matches = getAll()
        .where((c) => c.taskId == taskId && c.forWorkerId == forWorkerId);
    return matches.isEmpty ? null : matches.first;
  }
}

class HandoverRepository extends BaseRepository<Handover> {
  HandoverRepository()
      : super(
          Hive.box(HiveBoxes.handovers),
          toMap: (h) => h.toMap(),
          fromMap: (m) => Handover.fromMap(m),
        );

  List<Handover> forCollection(String collectionId) =>
      getAll().where((h) => h.collectionId == collectionId).toList();

  int totalHandedOverBy(String collectorWorkerId) => getAll()
      .where((h) => h.collectorWorkerId == collectorWorkerId)
      .fold(0, (sum, h) => sum + h.amount);
}

class AuditLogRepository extends BaseRepository<AuditLog> {
  AuditLogRepository()
      : super(
          Hive.box(HiveBoxes.auditLogs),
          toMap: (a) => a.toMap(),
          fromMap: (m) => AuditLog.fromMap(m),
        );

  List<AuditLog> forTask(String taskId) =>
      getAll().where((a) => a.taskId == taskId).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<AuditLog> forWorker(String workerId) =>
      getAll().where((a) => a.workerId == workerId).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<AuditLog> recent({int limit = 30}) {
    final all = getAll()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.take(limit).toList();
  }
}
