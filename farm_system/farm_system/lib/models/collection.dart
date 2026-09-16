import '../core/constants/enums.dart';

/// A real relationship record, not a plain-text "Collected By" field
/// (spec section 14). Links a collector Worker to an original Worker for
/// a specific amount on a specific task. One collector can have many
/// Collection rows (one per person they collect for) — see Rule 7/8.
class Collection {
  final String id;
  final String taskId;
  final String collectorWorkerId;
  final String forWorkerId;
  final String allocationId;
  final int amount;
  final DateTime collectedAt;
  final String recordedBy;
  final CollectionStatus status; // collected -> handedOver
  final String? note;

  const Collection({
    required this.id,
    required this.taskId,
    required this.collectorWorkerId,
    required this.forWorkerId,
    required this.allocationId,
    required this.amount,
    required this.collectedAt,
    required this.recordedBy,
    this.status = CollectionStatus.collected,
    this.note,
  });

  Collection markHandedOver() => Collection(
        id: id,
        taskId: taskId,
        collectorWorkerId: collectorWorkerId,
        forWorkerId: forWorkerId,
        allocationId: allocationId,
        amount: amount,
        collectedAt: collectedAt,
        recordedBy: recordedBy,
        status: CollectionStatus.handedOver,
        note: note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'collectorWorkerId': collectorWorkerId,
        'forWorkerId': forWorkerId,
        'allocationId': allocationId,
        'amount': amount,
        'collectedAt': collectedAt.toIso8601String(),
        'recordedBy': recordedBy,
        'status': status.name,
        'note': note,
      };

  factory Collection.fromMap(Map map) => Collection(
        id: map['id'] as String,
        taskId: map['taskId'] as String,
        collectorWorkerId: map['collectorWorkerId'] as String,
        forWorkerId: map['forWorkerId'] as String,
        allocationId: map['allocationId'] as String,
        amount: map['amount'] as int,
        collectedAt: DateTime.parse(map['collectedAt'] as String),
        recordedBy: map['recordedBy'] as String,
        status: CollectionStatus.values.byName(map['status'] as String),
        note: map['note'] as String?,
      );
}
