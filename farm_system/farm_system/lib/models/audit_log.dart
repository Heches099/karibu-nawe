import '../core/constants/enums.dart';

/// Append-only audit trail. Rule 11/12: financial history is never
/// silently deleted or overwritten, and every meaningful adjustment must
/// be traceable to a user, a time, and (where relevant) a reason.
class AuditLog {
  final String id;
  final AuditAction action;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final String? taskId;
  final String? workerId;
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final String description; // human-readable summary for the activity feed

  const AuditLog({
    required this.id,
    required this.action,
    required this.userId,
    required this.userName,
    required this.timestamp,
    this.taskId,
    this.workerId,
    this.oldValue,
    this.newValue,
    this.reason,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'action': action.name,
        'userId': userId,
        'userName': userName,
        'timestamp': timestamp.toIso8601String(),
        'taskId': taskId,
        'workerId': workerId,
        'oldValue': oldValue,
        'newValue': newValue,
        'reason': reason,
        'description': description,
      };

  factory AuditLog.fromMap(Map map) => AuditLog(
        id: map['id'] as String,
        action: AuditAction.values.byName(map['action'] as String),
        userId: map['userId'] as String,
        userName: map['userName'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        taskId: map['taskId'] as String?,
        workerId: map['workerId'] as String?,
        oldValue: map['oldValue'] as String?,
        newValue: map['newValue'] as String?,
        reason: map['reason'] as String?,
        description: map['description'] as String,
      );
}
