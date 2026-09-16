import 'enums.dart';

/// Immutable audit record. Every meaningful financial / operational action
/// creates one of these. History is never silently deleted or overwritten.
class AuditLog {
  final String id;
  final AuditActionType action;
  final String actor;
  final String? taskId;
  final String? workerId;
  final String? allocationId;
  final String? paymentId;
  final String? collectionId;
  final String? handoverId;
  final Map<String, dynamic> oldValue;
  final Map<String, dynamic> newValue;
  final String? reason;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.action,
    required this.actor,
    this.taskId,
    this.workerId,
    this.allocationId,
    this.paymentId,
    this.collectionId,
    this.handoverId,
    this.oldValue = const {},
    this.newValue = const {},
    this.reason,
    required this.createdAt,
  });

  factory AuditLog.create({
    required AuditActionType action,
    required String actor,
    String? taskId,
    String? workerId,
    String? allocationId,
    String? paymentId,
    String? collectionId,
    String? handoverId,
    Map<String, dynamic> oldValue = const {},
    Map<String, dynamic> newValue = const {},
    String? reason,
  }) =>
      AuditLog(
        id: '',
        action: action,
        actor: actor,
        taskId: taskId,
        workerId: workerId,
        allocationId: allocationId,
        paymentId: paymentId,
        collectionId: collectionId,
        handoverId: handoverId,
        oldValue: oldValue,
        newValue: newValue,
        reason: reason,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'action': action.index,
        'actor': actor,
        'taskId': taskId,
        'workerId': workerId,
        'allocationId': allocationId,
        'paymentId': paymentId,
        'collectionId': collectionId,
        'handoverId': handoverId,
        'oldValue': oldValue,
        'newValue': newValue,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuditLog.fromMap(Map<String, dynamic> m) => AuditLog(
        id: m['id'] as String,
        action: AuditActionType.values[m['action'] as int],
        actor: m['actor'] as String? ?? '',
        taskId: m['taskId'] as String?,
        workerId: m['workerId'] as String?,
        allocationId: m['allocationId'] as String?,
        paymentId: m['paymentId'] as String?,
        collectionId: m['collectionId'] as String?,
        handoverId: m['handoverId'] as String?,
        oldValue: Map<String, dynamic>.from(m['oldValue'] as Map? ?? {}),
        newValue: Map<String, dynamic>.from(m['newValue'] as Map? ?? {}),
        reason: m['reason'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}