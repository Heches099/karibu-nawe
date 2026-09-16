import '../core/constants/enums.dart';

/// Records the collector actually giving the money to the original
/// worker. Rule 9: Collection and Handover are different states — a
/// Collection existing does NOT imply money has reached its owner.
class Handover {
  final String id;
  final String collectionId;
  final String collectorWorkerId;
  final String originalWorkerId;
  final int amount;
  final DateTime handedOverAt;
  final String receivedBy; // usually the original worker's name/confirmation
  final HandoverStatus status;
  final String recordedBy;
  final String? note;

  const Handover({
    required this.id,
    required this.collectionId,
    required this.collectorWorkerId,
    required this.originalWorkerId,
    required this.amount,
    required this.handedOverAt,
    required this.receivedBy,
    this.status = HandoverStatus.completed,
    required this.recordedBy,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'collectionId': collectionId,
        'collectorWorkerId': collectorWorkerId,
        'originalWorkerId': originalWorkerId,
        'amount': amount,
        'handedOverAt': handedOverAt.toIso8601String(),
        'receivedBy': receivedBy,
        'status': status.name,
        'recordedBy': recordedBy,
        'note': note,
      };

  factory Handover.fromMap(Map map) => Handover(
        id: map['id'] as String,
        collectionId: map['collectionId'] as String,
        collectorWorkerId: map['collectorWorkerId'] as String,
        originalWorkerId: map['originalWorkerId'] as String,
        amount: map['amount'] as int,
        handedOverAt: DateTime.parse(map['handedOverAt'] as String),
        receivedBy: map['receivedBy'] as String,
        status: HandoverStatus.values.byName(map['status'] as String),
        recordedBy: map['recordedBy'] as String,
        note: map['note'] as String?,
      );
}
