import 'enums.dart';

/// A single payment transaction against a worker's allocation.
class Payment {
  final String id;
  final String taskId;
  final String workerId;
  final String? allocationId;
  final double amount;
  final DateTime paidAt;
  final String method;
  final String? note;
  final String recordedBy;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.taskId,
    required this.workerId,
    this.allocationId,
    required this.amount,
    required this.paidAt,
    this.method = '',
    this.note,
    required this.recordedBy,
    required this.createdAt,
  });

  factory Payment.create({
    required String taskId,
    required String workerId,
    String? allocationId,
    required double amount,
    required DateTime paidAt,
    String method = '',
    String? note,
    required String recordedBy,
  }) =>
      Payment(
        id: '',
        taskId: taskId,
        workerId: workerId,
        allocationId: allocationId,
        amount: amount,
        paidAt: paidAt,
        method: method,
        note: note,
        recordedBy: recordedBy,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'workerId': workerId,
        'allocationId': allocationId,
        'amount': amount,
        'paidAt': paidAt.toIso8601String(),
        'method': method,
        'note': note,
        'recordedBy': recordedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id'] as String,
        taskId: m['taskId'] as String,
        workerId: m['workerId'] as String,
        allocationId: m['allocationId'] as String?,
        amount: (m['amount'] as num).toDouble(),
        paidAt: DateTime.parse(m['paidAt'] as String),
        method: m['method'] as String? ?? '',
        note: m['note'] as String?,
        recordedBy: m['recordedBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

/// Links a collector to another worker's money.
///
/// `workerId` is the worker the money belongs to (for whom).
/// `collectorId` is the worker who physically collected the cash.
class Collection {
  final String id;
  final String taskId;
  final String workerId; // for whom
  final String collectorId; // who collected
  final double amount;
  final DateTime collectedAt;
  final String? note;
  final String recordedBy;
  final CollectionStatus status;
  final DateTime createdAt;

  const Collection({
    required this.id,
    required this.taskId,
    required this.workerId,
    required this.collectorId,
    required this.amount,
    required this.collectedAt,
    this.note,
    required this.recordedBy,
    this.status = CollectionStatus.collected,
    required this.createdAt,
  });

  factory Collection.create({
    required String taskId,
    required String workerId,
    required String collectorId,
    required double amount,
    required DateTime collectedAt,
    String? note,
    required String recordedBy,
  }) =>
      Collection(
        id: '',
        taskId: taskId,
        workerId: workerId,
        collectorId: collectorId,
        amount: amount,
        collectedAt: collectedAt,
        note: note,
        recordedBy: recordedBy,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'workerId': workerId,
        'collectorId': collectorId,
        'amount': amount,
        'collectedAt': collectedAt.toIso8601String(),
        'note': note,
        'recordedBy': recordedBy,
        'status': status.index,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Collection.fromMap(Map<String, dynamic> m) => Collection(
        id: m['id'] as String,
        taskId: m['taskId'] as String,
        workerId: m['workerId'] as String,
        collectorId: m['collectorId'] as String,
        amount: (m['amount'] as num).toDouble(),
        collectedAt: DateTime.parse(m['collectedAt'] as String),
        note: m['note'] as String?,
        recordedBy: m['recordedBy'] as String? ?? '',
        status: CollectionStatus.values[m['status'] as int? ?? 0],
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

/// A handover transaction: a collector physically gives money to the original
/// worker (or another receiver). Handover does not replace collection.
class Handover {
  final String id;
  final String collectorId;
  final String workerId; // original worker receiving
  final String? taskId;
  final double amount;
  final DateTime handedAt;
  final String receivedByWorkerId;
  final String? note;
  final String recordedBy;
  final HandoverStatus status;
  final DateTime createdAt;

  const Handover({
    required this.id,
    required this.collectorId,
    required this.workerId,
    this.taskId,
    required this.amount,
    required this.handedAt,
    required this.receivedByWorkerId,
    this.note,
    required this.recordedBy,
    this.status = HandoverStatus.completed,
    required this.createdAt,
  });

  factory Handover.create({
    required String collectorId,
    required String workerId,
    String? taskId,
    required double amount,
    required DateTime handedAt,
    required String receivedByWorkerId,
    String? note,
    required String recordedBy,
  }) =>
      Handover(
        id: '',
        collectorId: collectorId,
        workerId: workerId,
        taskId: taskId,
        amount: amount,
        handedAt: handedAt,
        receivedByWorkerId: receivedByWorkerId,
        note: note,
        recordedBy: recordedBy,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'collectorId': collectorId,
        'workerId': workerId,
        'taskId': taskId,
        'amount': amount,
        'handedAt': handedAt.toIso8601String(),
        'receivedByWorkerId': receivedByWorkerId,
        'note': note,
        'recordedBy': recordedBy,
        'status': status.index,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Handover.fromMap(Map<String, dynamic> m) => Handover(
        id: m['id'] as String,
        collectorId: m['collectorId'] as String,
        workerId: m['workerId'] as String,
        taskId: m['taskId'] as String?,
        amount: (m['amount'] as num).toDouble(),
        handedAt: DateTime.parse(m['handedAt'] as String),
        receivedByWorkerId: m['receivedByWorkerId'] as String? ?? m['workerId'] as String,
        note: m['note'] as String?,
        recordedBy: m['recordedBy'] as String? ?? '',
        status: HandoverStatus.values[m['status'] as int? ?? 0],
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}