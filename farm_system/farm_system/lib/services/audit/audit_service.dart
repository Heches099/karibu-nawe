import '../../core/constants/enums.dart';
import '../../core/utils/id_generator.dart';
import '../../models/audit_log.dart';
import '../../models/user.dart';
import '../../repositories/repositories.dart';

/// Every write path in the app that matters financially or operationally
/// goes through here afterwards (spec section 25). Kept as one small
/// service so "what counts as an auditable action" is defined in exactly
/// one place.
class AuditService {
  AuditService(this._repo);
  final AuditLogRepository _repo;

  Future<void> log({
    required AuditAction action,
    required AppUser actor,
    required String description,
    String? taskId,
    String? workerId,
    String? oldValue,
    String? newValue,
    String? reason,
  }) async {
    final entry = AuditLog(
      id: IdGenerator.next(),
      action: action,
      userId: actor.id,
      userName: actor.name,
      timestamp: DateTime.now(),
      taskId: taskId,
      workerId: workerId,
      oldValue: oldValue,
      newValue: newValue,
      reason: reason,
      description: description,
    );
    await _repo.put(entry.id, entry);
  }
}
