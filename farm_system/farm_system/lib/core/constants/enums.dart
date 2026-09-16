/// All status/enum values in the system are modelled as Dart enums but
/// persisted as plain strings in Hive (via `.name` / `byName`) so the
/// storage format stays human-readable and stable across app versions.
library;

enum TaskStatus { active, completed, cancelled }

enum PaymentStatus { unpaid, partial, paid }

enum CollectionStatus { collected, handedOver }

enum HandoverStatus { pending, completed }

enum UserRole { boss, manager, clerk }

/// The identifiers of the built-in work types. "custom" allows the Boss
/// to define an ad-hoc work type without changing the app.
enum WorkTypeId { kupalilia, kupigaDawa, kupanda, kuvuna, mbolea, custom }

/// The category drives which calculator UI + formula is used.
/// Adding a new category means adding one calculator, not rewriting
/// the app — see [services/calculation/calculation_engine.dart].
enum CalculationCategory {
  areaFixedPayment, // area measured, a flat agreed payment is entered
  areaWithRate, // area measured, paid per m² (e.g. kuvuna per kg/area)
  sprayingChemical, // area + coverage + price per litre
  quantityWithRate, // e.g. kg harvested x price per kg
  customFormula, // free-form, manager supplies the expected amount directly
}

enum AuditAction {
  taskCreated,
  taskUpdated,
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
}

extension TaskStatusX on TaskStatus {
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

extension PaymentStatusX on PaymentStatus {
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

extension WorkTypeIdX on WorkTypeId {
  String get displayName {
    switch (this) {
      case WorkTypeId.kupalilia:
        return 'Kupalilia';
      case WorkTypeId.kupigaDawa:
        return 'Kupiga Dawa';
      case WorkTypeId.kupanda:
        return 'Kupanda';
      case WorkTypeId.kuvuna:
        return 'Kuvuna';
      case WorkTypeId.mbolea:
        return 'Mbolea';
      case WorkTypeId.custom:
        return 'Other / Custom';
    }
  }
}
