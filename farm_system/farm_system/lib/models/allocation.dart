
/// Links one Worker to one Task with their own Expected/Allocated amounts.
///
/// Rule 3: Allocated Amount belongs to an individual worker.
/// Rule 2: expectedAmount is copied from the Calculation at creation time
/// and is never overwritten by an allocation change — only `allocatedAmount`
/// moves. The full history of how allocatedAmount changed lives in
/// [AllocationAdjustment] records (see below), never collapsed into this row.
class Allocation {
  final String id;
  final String taskId;
  final String workerId;
  final String calculationId;

  final int expectedAmount; // copied from Calculation.expectedAmount, frozen
  final int allocatedAmount; // current allocated amount (may differ from expected)

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Allocation({
    required this.id,
    required this.taskId,
    required this.workerId,
    required this.calculationId,
    required this.expectedAmount,
    required this.allocatedAmount,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  int get difference => allocatedAmount - expectedAmount;
  bool get isAdjusted => difference != 0;

  Allocation withNewAllocatedAmount(int amount) => Allocation(
        id: id,
        taskId: taskId,
        workerId: workerId,
        calculationId: calculationId,
        expectedAmount: expectedAmount,
        allocatedAmount: amount,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'workerId': workerId,
        'calculationId': calculationId,
        'expectedAmount': expectedAmount,
        'allocatedAmount': allocatedAmount,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Allocation.fromMap(Map map) => Allocation(
        id: map['id'] as String,
        taskId: map['taskId'] as String,
        workerId: map['workerId'] as String,
        calculationId: map['calculationId'] as String,
        expectedAmount: map['expectedAmount'] as int,
        allocatedAmount: map['allocatedAmount'] as int,
        createdBy: map['createdBy'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
}

/// One row per change to an Allocation's allocatedAmount. Rule 4 + Rule 11:
/// a reason is mandatory whenever allocated != expected, and this history
/// is append-only — never edited or deleted.
class AllocationAdjustment {
  final String id;
  final String allocationId;
  final int previousAmount;
  final int newAmount;
  final String reason;
  final String changedBy;
  final DateTime changedAt;

  const AllocationAdjustment({
    required this.id,
    required this.allocationId,
    required this.previousAmount,
    required this.newAmount,
    required this.reason,
    required this.changedBy,
    required this.changedAt,
  });

  int get delta => newAmount - previousAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'allocationId': allocationId,
        'previousAmount': previousAmount,
        'newAmount': newAmount,
        'reason': reason,
        'changedBy': changedBy,
        'changedAt': changedAt.toIso8601String(),
      };

  factory AllocationAdjustment.fromMap(Map map) => AllocationAdjustment(
        id: map['id'] as String,
        allocationId: map['allocationId'] as String,
        previousAmount: map['previousAmount'] as int,
        newAmount: map['newAmount'] as int,
        reason: map['reason'] as String,
        changedBy: map['changedBy'] as String,
        changedAt: DateTime.parse(map['changedAt'] as String),
      );
}
