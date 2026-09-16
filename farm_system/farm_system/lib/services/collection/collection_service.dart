import '../../core/constants/enums.dart';
import '../../core/utils/id_generator.dart';
import '../../models/allocation.dart';
import '../../models/collection.dart';
import '../../models/handover.dart';
import '../../models/user.dart';
import '../../repositories/repositories.dart';
import '../audit/audit_service.dart';
import '../payment/payment_service.dart';

class CollectionValidationError implements Exception {
  final String message;
  CollectionValidationError(this.message);
  @override
  String toString() => message;
}

/// Owns the Collection/Handover relationship (spec sections 14–18,
/// Rules 7–10). A collection never implies handover; handover can never
/// exceed what was actually collected.
class CollectionService {
  CollectionService({
    required CollectionRepository collectionRepo,
    required HandoverRepository handoverRepo,
    required AuditService auditService,
    required PaymentService paymentService,
  })  : _collectionRepo = collectionRepo,
        _handoverRepo = handoverRepo,
        _audit = auditService,
        _payments = paymentService;

  final CollectionRepository _collectionRepo;
  final HandoverRepository _handoverRepo;
  final AuditService _audit;
  final PaymentService _payments;

  /// Registers that [collectorWorkerId] is collecting money on behalf of
  /// [forWorkerId] for a specific allocation. Rule 7: one collector can
  /// have many of these records (one per worker they collect for).
  Future<Collection> assignCollector({
    required Allocation allocation,
    required String collectorWorkerId,
    required int amount,
    required AppUser actor,
    String? note,
  }) async {
    if (collectorWorkerId == allocation.workerId) {
      throw CollectionValidationError('A worker cannot be recorded as collecting their own money.');
    }
    if (amount <= 0) {
      throw CollectionValidationError('Collection amount must be greater than zero.');
    }
    final remaining = _payments.remaining(allocation);
    if (amount > remaining) {
      throw CollectionValidationError(
          'Collection amount (TSh $amount) cannot exceed the worker\'s remaining balance (TSh $remaining).');
    }

    final existing = _collectionRepo.forAllocation(allocation.id);
    if (existing.isNotEmpty) {
      throw CollectionValidationError('A collector is already assigned for this allocation.');
    }

    final collection = Collection(
      id: IdGenerator.next(),
      taskId: allocation.taskId,
      collectorWorkerId: collectorWorkerId,
      forWorkerId: allocation.workerId,
      allocationId: allocation.id,
      amount: amount,
      collectedAt: DateTime.now(),
      recordedBy: actor.id,
      note: note,
    );
    await _collectionRepo.put(collection.id, collection);

    // The money has left the Boss's hand into the collector's — for the
    // worker's own bookkeeping this counts as paid, just routed through
    // a collector instead of handed to them directly. Recording it as a
    // Payment keeps the Worksheet's Paid/Remaining figures accurate
    // without requiring a second, separate "mark as paid" step.
    await _payments.recordPayment(
      allocation: allocation,
      amount: amount,
      actor: actor,
      method: 'Via collector',
      note: note,
    );

    await _audit.log(
      action: AuditAction.collectorAssigned,
      actor: actor,
      taskId: allocation.taskId,
      workerId: allocation.workerId,
      newValue: 'Collector: $collectorWorkerId, Amount: TSh $amount',
      description: 'Collector assigned to collect TSh $amount on behalf of worker',
    );
    await _audit.log(
      action: AuditAction.collectionCreated,
      actor: actor,
      taskId: allocation.taskId,
      workerId: allocation.workerId,
      description: 'Collection of TSh $amount recorded',
    );

    return collection;
  }

  /// Rule 9: Handover is a separate, later event. Rule: handover cannot
  /// exceed the amount collected (minus anything already handed over).
  Future<Handover> completeHandover({
    required Collection collection,
    required String receivedBy,
    required AppUser actor,
    int? amount,
    String? note,
  }) async {
    final alreadyHandedOver = _handoverRepo
        .forCollection(collection.id)
        .fold<int>(0, (sum, h) => sum + h.amount);
    final remaining = collection.amount - alreadyHandedOver;
    final handoverAmount = amount ?? remaining;

    if (handoverAmount <= 0) {
      throw CollectionValidationError('Nothing remains to hand over for this collection.');
    }
    if (handoverAmount > remaining) {
      throw CollectionValidationError(
          'Handover (TSh $handoverAmount) exceeds amount still held (TSh $remaining).');
    }

    final handover = Handover(
      id: IdGenerator.next(),
      collectionId: collection.id,
      collectorWorkerId: collection.collectorWorkerId,
      originalWorkerId: collection.forWorkerId,
      amount: handoverAmount,
      handedOverAt: DateTime.now(),
      receivedBy: receivedBy,
      recordedBy: actor.id,
      note: note,
    );
    await _handoverRepo.put(handover.id, handover);

    // If fully handed over, flip the Collection's status for quick filtering.
    if (handoverAmount == remaining) {
      final updated = collection.markHandedOver();
      await _collectionRepo.put(updated.id, updated);
    }

    await _audit.log(
      action: AuditAction.handoverCompleted,
      actor: actor,
      taskId: collection.taskId,
      workerId: collection.forWorkerId,
      newValue: 'TSh $handoverAmount',
      description: 'Handover of TSh $handoverAmount completed to ${collection.forWorkerId}',
    );

    return handover;
  }

  int pendingHandoverFor(Collection collection) {
    final handedOver = _handoverRepo
        .forCollection(collection.id)
        .fold<int>(0, (sum, h) => sum + h.amount);
    return collection.amount - handedOver;
  }
}
