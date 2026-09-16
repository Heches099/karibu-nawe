import 'enums.dart';

/// Money assigned to an individual worker for a task.
///
/// [expectedAmount] is frozen at the baseline expected value for this worker.
/// [allocatedAmount] is the current actual allocation. Whenever it is changed,
/// an `AllocationAdjustment` record is written so the history is preserved.
class Allocation {
  final String id;
  final String taskId;
  final String workerId;
  final double expectedAmount;
  final double allocatedAmount;
  final AllocationStatus status;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Allocation({
    required this.id,
    required this.taskId,
    required this.workerId,
    required this.expectedAmount,
    required this.allocatedAmount,
    this.status = AllocationStatus.active,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Allocation.create({
    required String taskId,
    required String workerId,
    required double expectedAmount,
    required double allocatedAmount,
    String? notes,
    required String createdBy,
  }) =>
      Allocation(
        id: '',
        taskId: taskId,
        workerId: workerId,
        expectedAmount: expectedAmount,
        allocatedAmount: allocatedAmount,
        notes: notes,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  double get adjustment => allocatedAmount - expectedAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'workerId': workerId,
        'expectedAmount': expectedAmount,
        'allocatedAmount': allocatedAmount,
        'status': status.index,
        'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Allocation.fromMap(Map<String, dynamic> m) => Allocation(
        id: m['id'] as String,
        taskId: m['taskId'] as String,
        workerId: m['workerId'] as String,
        expectedAmount: (m['expectedAmount'] as num).toDouble(),
        allocatedAmount: (m['allocatedAmount'] as num).toDouble(),
        status: AllocationStatus.values[m['status'] as int? ?? 0],
        notes: m['notes'] as String?,
        createdBy: m['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}

/// Keeps a full history of allocation changes.
class AllocationAdjustment {
  final String id;
  final String allocationId;
  final String taskId;
  final String workerId;
  final double fromAmount;
  final double toAmount;
  final String reason;
  final String changedBy;
  final DateTime createdAt;

  const AllocationAdjustment({
    required this.id,
    required this.allocationId,
    required this.taskId,
    required this.workerId,
    required this.fromAmount,
    required this.toAmount,
    required this.reason,
    required this.changedBy,
    required this.createdAt,
  });

  factory AllocationAdjustment.create({
    required String taskId,
    required String workerId,
    required double fromAmount,
    required double toAmount,
    required String reason,
    required String changedBy,
  }) =>
      AllocationAdjustment(
        id: '',
        allocationId: '',
        taskId: taskId,
        workerId: workerId,
        fromAmount: fromAmount,
        toAmount: toAmount,
        reason: reason,
        changedBy: changedBy,
        createdAt: DateTime.now(),
      );

  double get difference => toAmount - fromAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'allocationId': allocationId,
        'taskId': taskId,
        'workerId': workerId,
        'fromAmount': fromAmount,
        'toAmount': toAmount,
        'reason': reason,
        'changedBy': changedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AllocationAdjustment.fromMap(Map<String, dynamic> m) =>
      AllocationAdjustment(
        id: m['id'] as String,
        allocationId: m['allocationId'] as String,
        taskId: m['taskId'] as String,
        workerId: m['workerId'] as String,
        fromAmount: (m['fromAmount'] as num).toDouble(),
        toAmount: (m['toAmount'] as num).toDouble(),
        reason: m['reason'] as String? ?? '',
        changedBy: m['changedBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}