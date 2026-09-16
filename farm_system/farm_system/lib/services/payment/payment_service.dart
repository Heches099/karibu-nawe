import '../../core/constants/enums.dart';
import '../../core/utils/id_generator.dart';
import '../../models/allocation.dart';
import '../../models/calculation.dart';
import '../../models/payment.dart';
import '../../models/user.dart';
import '../../repositories/repositories.dart';
import '../audit/audit_service.dart';

class PaymentValidationError implements Exception {
  final String message;
  PaymentValidationError(this.message);
  @override
  String toString() => message;
}

/// Owns every rule around Allocation + Payment (spec Rules 2–6, 11).
/// UI widgets never touch the repositories directly for these actions —
/// they go through here so the rules can't be bypassed accidentally.
class PaymentService {
  PaymentService({
    required AllocationRepository allocationRepo,
    required AllocationAdjustmentRepository adjustmentRepo,
    required PaymentRepository paymentRepo,
    required AuditService auditService,
  })  : _allocationRepo = allocationRepo,
        _adjustmentRepo = adjustmentRepo,
        _paymentRepo = paymentRepo,
        _audit = auditService;

  final AllocationRepository _allocationRepo;
  final AllocationAdjustmentRepository _adjustmentRepo;
  final PaymentRepository _paymentRepo;
  final AuditService _audit;

  /// Creates the initial Allocation for a worker on a task. By default
  /// Allocated = Expected (Rule: "Normally Expected = Allocated").
  Future<Allocation> createAllocation({
    required String taskId,
    required String workerId,
    required Calculation calculation,
    required AppUser actor,
    int? initialAllocatedAmount,
    String? reasonIfDifferent,
  }) async {
    final allocated = initialAllocatedAmount ?? calculation.expectedAmount;

    if (allocated < 0) {
      throw PaymentValidationError('Allocated amount cannot be negative.');
    }
    if (allocated != calculation.expectedAmount &&
        (reasonIfDifferent == null || reasonIfDifferent.trim().isEmpty)) {
      throw PaymentValidationError(
          'A reason is required because the allocated amount differs from the expected amount.');
    }

    final now = DateTime.now();
    final allocation = Allocation(
      id: IdGenerator.next(),
      taskId: taskId,
      workerId: workerId,
      calculationId: calculation.id,
      expectedAmount: calculation.expectedAmount,
      allocatedAmount: allocated,
      createdBy: actor.id,
      createdAt: now,
      updatedAt: now,
    );
    await _allocationRepo.put(allocation.id, allocation);

    await _audit.log(
      action: AuditAction.allocationCreated,
      actor: actor,
      taskId: taskId,
      workerId: workerId,
      newValue: allocated.toString(),
      description: 'Allocation created for worker (TSh $allocated)',
    );

    if (allocation.isAdjusted) {
      final adjustment = AllocationAdjustment(
        id: IdGenerator.next(),
        allocationId: allocation.id,
        previousAmount: calculation.expectedAmount,
        newAmount: allocated,
        reason: reasonIfDifferent!.trim(),
        changedBy: actor.id,
        changedAt: now,
      );
      await _adjustmentRepo.put(adjustment.id, adjustment);
      await _audit.log(
        action: AuditAction.adjustmentMade,
        actor: actor,
        taskId: taskId,
        workerId: workerId,
        oldValue: calculation.expectedAmount.toString(),
        newValue: allocated.toString(),
        reason: reasonIfDifferent,
        description:
            'Allocation set to TSh $allocated (expected TSh ${calculation.expectedAmount})',
      );
    }

    return allocation;
  }

  /// Rule 4: reason is mandatory whenever allocated != expected.
  /// Rule 11: never overwrite history — append a new adjustment record.
  Future<Allocation> adjustAllocation({
    required Allocation allocation,
    required int newAmount,
    required String reason,
    required AppUser actor,
  }) async {
    if (newAmount < 0) {
      throw PaymentValidationError('Allocated amount cannot be negative.');
    }
    if (newAmount == allocation.allocatedAmount) {
      throw PaymentValidationError('New amount is the same as the current amount.');
    }
    if (newAmount != allocation.expectedAmount && reason.trim().isEmpty) {
      throw PaymentValidationError(
          'A reason is required because the allocated amount differs from the expected amount.');
    }

    final previous = allocation.allocatedAmount;
    final updated = allocation.withNewAllocatedAmount(newAmount);
    await _allocationRepo.put(updated.id, updated);

    final adjustment = AllocationAdjustment(
      id: IdGenerator.next(),
      allocationId: allocation.id,
      previousAmount: previous,
      newAmount: newAmount,
      reason: reason.trim().isEmpty
          ? 'No reason provided (amount restored to expected)'
          : reason.trim(),
      changedBy: actor.id,
      changedAt: DateTime.now(),
    );
    await _adjustmentRepo.put(adjustment.id, adjustment);

    await _audit.log(
      action: AuditAction.allocationModified,
      actor: actor,
      taskId: allocation.taskId,
      workerId: allocation.workerId,
      oldValue: previous.toString(),
      newValue: newAmount.toString(),
      reason: reason,
      description: 'Allocation changed: TSh $previous → TSh $newAmount',
    );

    return updated;
  }

  /// Rule 5/6: payment is independent, remaining is always derived.
  Future<Payment> recordPayment({
    required Allocation allocation,
    required int amount,
    required AppUser actor,
    String? method,
    String? note,
    DateTime? paidAt,
  }) async {
    if (amount <= 0) {
      throw PaymentValidationError('Payment amount must be greater than zero.');
    }
    final alreadyPaid = _paymentRepo.totalPaidForAllocation(allocation.id);
    final remaining = allocation.allocatedAmount - alreadyPaid;
    if (amount > remaining) {
      throw PaymentValidationError(
          'Payment (TSh $amount) exceeds remaining balance (TSh $remaining).');
    }

    final payment = Payment(
      id: IdGenerator.next(),
      allocationId: allocation.id,
      taskId: allocation.taskId,
      workerId: allocation.workerId,
      amount: amount,
      paidAt: paidAt ?? DateTime.now(),
      method: method,
      recordedBy: actor.id,
      note: note,
    );
    await _paymentRepo.put(payment.id, payment);

    await _audit.log(
      action: AuditAction.paymentCreated,
      actor: actor,
      taskId: allocation.taskId,
      workerId: allocation.workerId,
      newValue: amount.toString(),
      description: 'Payment of TSh $amount recorded',
    );

    return payment;
  }

  int totalPaid(String allocationId) => _paymentRepo.totalPaidForAllocation(allocationId);

  int remaining(Allocation allocation) =>
      allocation.allocatedAmount - totalPaid(allocation.id);

  PaymentStatus statusFor(Allocation allocation) {
    final paid = totalPaid(allocation.id);
    if (paid <= 0) return PaymentStatus.unpaid;
    if (paid >= allocation.allocatedAmount) return PaymentStatus.paid;
    return PaymentStatus.partial;
  }
}
