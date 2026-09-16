/// A single payment transaction against an Allocation. Rule 5: payment is
/// independent from allocation. Multiple Payment rows accumulate toward
/// Allocation.allocatedAmount; Remaining is always derived, never stored
/// as an editable field (Rule 6 / Rule 11 — nothing here can silently
/// drift out of sync because it isn't stored twice).
class Payment {
  final String id;
  final String allocationId;
  final String taskId;
  final String workerId;
  final int amount;
  final DateTime paidAt;
  final String? method; // cash, mobile money, bank, etc.
  final String recordedBy;
  final String? note;

  const Payment({
    required this.id,
    required this.allocationId,
    required this.taskId,
    required this.workerId,
    required this.amount,
    required this.paidAt,
    this.method,
    required this.recordedBy,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'allocationId': allocationId,
        'taskId': taskId,
        'workerId': workerId,
        'amount': amount,
        'paidAt': paidAt.toIso8601String(),
        'method': method,
        'recordedBy': recordedBy,
        'note': note,
      };

  factory Payment.fromMap(Map map) => Payment(
        id: map['id'] as String,
        allocationId: map['allocationId'] as String,
        taskId: map['taskId'] as String,
        workerId: map['workerId'] as String,
        amount: map['amount'] as int,
        paidAt: DateTime.parse(map['paidAt'] as String),
        method: map['method'] as String?,
        recordedBy: map['recordedBy'] as String,
        note: map['note'] as String?,
      );
}
