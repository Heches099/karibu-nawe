import '../../models/audit_log.dart';
import '../../models/enums.dart';

/// Builds rich [AuditLog] entries. Business state changes are not complete
/// without an audit record.
class AuditService {
  const AuditService();

  AuditLog taskCreated({
    required String actor,
    required String taskId,
    required String title,
  }) =>
      AuditLog.create(
        action: AuditActionType.taskCreated,
        actor: actor,
        taskId: taskId,
        newValue: {'title': title},
      );

  AuditLog workerAdded({
    required String actor,
    required String workerId,
    required String name,
  }) =>
      AuditLog.create(
        action: AuditActionType.workerAdded,
        actor: actor,
        workerId: workerId,
        newValue: {'name': name},
      );

  AuditLog calculationSaved({
    required String actor,
    required String taskId,
    required double expectedAmount,
    required Map<String, dynamic> outputs,
  }) =>
      AuditLog.create(
        action: AuditActionType.calculationSaved,
        actor: actor,
        taskId: taskId,
        newValue: {'expectedAmount': expectedAmount, 'outputs': outputs},
      );

  AuditLog allocationCreated({
    required String actor,
    required String taskId,
    required String workerId,
    required String allocationId,
    required double expectedAmount,
    required double allocatedAmount,
  }) =>
      AuditLog.create(
        action: AuditActionType.allocationCreated,
        actor: actor,
        taskId: taskId,
        workerId: workerId,
        allocationId: allocationId,
        newValue: {'expectedAmount': expectedAmount, 'allocatedAmount': allocatedAmount},
      );

  AuditLog allocationModified({
    required String actor,
    required String taskId,
    required String workerId,
    required String allocationId,
    required double fromAmount,
    required double toAmount,
    String? reason,
  }) {
    final adjusted = fromAmount != toAmount;
    return AuditLog.create(
      action: adjusted ? AuditActionType.adjustmentMade : AuditActionType.allocationModified,
      actor: actor,
      taskId: taskId,
      workerId: workerId,
      allocationId: allocationId,
      oldValue: {'allocatedAmount': fromAmount, 'expectedAmount-adjusted': adjusted},
      newValue: {'allocatedAmount': toAmount, 'expectedAmount-adjusted': adjusted},
      reason: reason,
    );
  }

  AuditLog paymentCreated({
    required String actor,
    required String taskId,
    required String workerId,
    required String paymentId,
    required double amount,
  }) =>
      AuditLog.create(
        action: AuditActionType.paymentCreated,
        actor: actor,
        taskId: taskId,
        workerId: workerId,
        paymentId: paymentId,
        newValue: {'amount': amount},
      );

  AuditLog collectorAssigned({
    required String actor,
    required String taskId,
    required String collectorId,
    required String workerId,
  }) =>
      AuditLog.create(
        action: AuditActionType.collectorAssigned,
        actor: actor,
        taskId: taskId,
        workerId: workerId,
        collectionId: collectorId,
        newValue: {'collectorId': collectorId},
      );

  AuditLog collectionCreated({
    required String actor,
    required String taskId,
    required String workerId,
    required String collectorId,
    required String collectionId,
    required double amount,
  }) =>
      AuditLog.create(
        action: AuditActionType.collectionCreated,
        actor: actor,
        taskId: taskId,
        workerId: workerId,
        collectionId: collectionId,
        newValue: {'collectorId': collectorId, 'amount': amount},
      );

  AuditLog handoverCompleted({
    required String actor,
    required String taskId,
    required String workerId,
    required String collectorId,
    required String handoverId,
    required double amount,
  }) =>
      AuditLog.create(
        action: AuditActionType.handoverCompleted,
        actor: actor,
        taskId: taskId,
        workerId: workerId,
        collectionId: collectorId,
        handoverId: handoverId,
        newValue: {'amount': amount, 'collectorId': collectorId},
      );

  AuditLog login({required String actor}) =>
      AuditLog.create(action: AuditActionType.login, actor: actor);
}