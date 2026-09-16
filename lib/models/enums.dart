enum UserRole { boss, manager, worker }

enum TaskStatus { active, completed, cancelled }

enum WorkZoneStatus { inProgress, completed, needsReview, blocked }

enum ProgressStatus { notStarted, inProgress, completed, needsReview, blocked }

enum AllocationStatus { active }

/// Derived from payments.
enum PaymentStatus { unpaid, partial, paid }

PaymentStatus derivePaymentStatus(num allocated, num totalPaid) {
  if (totalPaid <= 0) return PaymentStatus.unpaid;
  if (totalPaid >= allocated) return PaymentStatus.paid;
  return PaymentStatus.partial;
}

enum CollectionStatus { collected }

enum HandoverStatus { completed }

enum AuditActionType {
  taskCreated,
  workerAdded,
  calculationSaved,
  allocationCreated,
  allocationModified,
  adjustmentMade,
  paymentCreated,
  paymentUpdated,
  collectorAssigned,
  collectionCreated,
  handoverCompleted,
  workZoneCreated,
  workProgressUpdated,
  settingsUpdated,
  login,
}

extension TaskStatusDisplay on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.active:
        return 'Active';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }
}

extension PaymentStatusDisplay on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.paid:
        return 'Paid';
    }
  }
}

extension AuditActionTypeDisplay on AuditActionType {
  String get label => switch (this) {
        AuditActionType.taskCreated => 'Task Created',
        AuditActionType.workerAdded => 'Worker Added',
        AuditActionType.calculationSaved => 'Calculation Saved',
        AuditActionType.allocationCreated => 'Allocation Created',
        AuditActionType.allocationModified => 'Allocation Modified',
        AuditActionType.adjustmentMade => 'Adjustment Made',
        AuditActionType.paymentCreated => 'Payment Created',
        AuditActionType.paymentUpdated => 'Payment Updated',
        AuditActionType.collectorAssigned => 'Collector Assigned',
        AuditActionType.collectionCreated => 'Collection Created',
        AuditActionType.handoverCompleted => 'Handover Completed',
        AuditActionType.workZoneCreated => 'Work Zone Created',
        AuditActionType.workProgressUpdated => 'Work Progress Updated',
        AuditActionType.settingsUpdated => 'Settings Updated',
        AuditActionType.login => 'Login',
      };
}