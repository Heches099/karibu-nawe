# Farm Work Measurement, Allocation, Payment & Collection System

A Flutter application implementing the full financial pipeline:

```
WORK → MEASUREMENT → CALCULATION → EXPECTED AMOUNT → WORKER ALLOCATION
→ PAYMENT → COLLECTION FOR OTHERS → HANDOVER → LIVE MANAGEMENT
```

## Important — please read before anything else

I was not able to run, compile, or test this app in the sandbox I built it
in: there is no Flutter SDK installed there, and its network access is
restricted to a handful of package registries (npm, pip, cargo, GitHub) —
`pub.dev`, where Flutter/Dart packages live, is not reachable. So this
code has been written carefully and reviewed by hand, but **you are the
first one to actually run `flutter pub get` / `flutter run` against it.**
Treat it as a strong, complete first draft of a real codebase, not a
verified build. If something doesn't compile, it's most likely a small
naming/import slip — see "If something doesn't compile" below.

## What's real here vs. what's a placeholder

- **Persistence is real.** Every model is stored in [Hive](https://pub.dev/packages/hive),
  an embedded key-value database that writes to disk on Android/iOS/desktop
  and to IndexedDB on web. Data survives app restarts. No server needed to
  start using it today.
- **"Live" updates within the running app are real.** `AppState` listens to
  every Hive box's `ValueListenable`, so the moment any screen writes a
  payment, allocation, or collection, every other open screen (Dashboard,
  Worksheet, Worker Detail) rebuilds automatically via `Provider`/`Consumer`.
- **True multi-device realtime (Boss's phone updating when a clerk on
  another phone/PC enters a payment) is NOT implemented**, because that
  needs a real network backend (Firestore, Supabase, a custom API + web
  sockets, etc.), and this project intentionally keeps persistence behind
  a repository interface (`lib/repositories/`) so that swap is
  contained — see "Path to real multi-device sync" below.
- **Auth/roles are simplified.** `AppState.currentUser` is a single
  hard-coded Boss user. The `UserRole` enum and audit trail already
  record *who* did *what*, so wiring in real login (Firebase Auth, etc.)
  mainly means replacing this one field.

## Getting it running

```bash
flutter pub get
flutter run            # or: flutter run -d chrome / -d windows / -d macos
flutter test           # runs the calculation-engine unit tests
```

The app seeds realistic sample data on first launch (`lib/seed/seed_data.dart`)
covering every scenario in the spec: a flat-payment area job, a spraying
job, an allocation adjustment with a reason, a partial payment, a
one-collector-many-workers scenario, and both a completed and a pending
handover — so the Dashboard is never empty.

## Architecture

```
lib/
 ├── core/            constants (enums), theme, utils (currency/date/id)
 ├── models/          Task, Calculation, Allocation, AllocationAdjustment,
 │                    Payment, Collection, Handover, AuditLog, Worker,
 │                    WorkType, User — one class per concept, never merged
 ├── services/
 │    ├── calculation/  CalculationEngine — pure, unit-testable formulas
 │    ├── payment/      PaymentService — allocation + payment business rules
 │    ├── collection/   CollectionService — collector/handover rules
 │    └── audit/        AuditService — one place that defines what's audited
 ├── repositories/    one Hive-backed repository per model; UI never
 │                    touches Hive directly
 ├── state/           AppState — the single orchestrator the UI depends on
 ├── features/        one folder per screen area (dashboard, tasks,
 │                    calculator, allocations, workers, collections, audit)
 ├── shared/widgets/  StatusBadge, SummaryCard — reused everywhere so
 │                    status is always shown as text + icon + color
 └── seed/            realistic sample data for first run
```

Business logic never lives inside a widget's `build()` method — every
button calls into `AppState`, which delegates to a `Service`, which reads/
writes through a `Repository`. This is what makes the calculation engine
testable in isolation (`test/calculation_engine_test.dart`) with zero
Flutter/Hive dependencies.

## How each business rule from the spec is enforced in code

| Rule | Where |
|---|---|
| 1. Calculation generates the original Expected Amount | `CalculationEngine.calculate()` |
| 2. Expected Amount never silently changes | `Calculation` is immutable; a revision creates a **new** `Calculation` and marks the old one `isSuperseded` — nothing is overwritten (`AppState.saveCalculation`) |
| 3. Allocated Amount belongs to an individual worker | `Allocation.workerId` + `Allocation.allocatedAmount`, one row per worker per task |
| 4. Reason required when Allocated ≠ Expected | `PaymentService.createAllocation` / `adjustAllocation` throw `PaymentValidationError` if the reason is missing |
| 5. Payment independent of Allocation | `Payment` is its own model/repository; `Allocation.allocatedAmount` is never touched by recording a payment |
| 6. Remaining calculated automatically | `PaymentService.remaining()` — always derived, never stored |
| 7. One worker can collect for many others | `Collection.collectorWorkerId` is not unique — many `Collection` rows can share the same collector |
| 8. Every collection identifies who/for whom/how much/when | `Collection` model fields, all required (non-nullable) |
| 9. Collection ≠ Handover | Two separate models/repositories (`Collection`, `Handover`); `CollectionStatus` only flips to `handedOver` once a `Handover` covers the full amount |
| 10. A worker's own money is never mixed with money they collected | `WorkerDetailScreen` renders "Own Work & Earnings" and "Money Collected For Others" as two separate sections computed from two separate queries |
| 11. Financial history never silently deleted/overwritten | `AllocationAdjustment`, `Calculation` (superseding), `AuditLog`, and `Payment`/`Collection`/`Handover` are all append-only — repositories expose no "delete and replace" path for these |
| 12. Every meaningful adjustment is traceable | `AuditService.log()` is called from every mutating method in `PaymentService` and `CollectionService` |

## Known gaps / where I stopped short, and why

Given the scope of the spec (this is realistically a multi-week project
for a small team), I prioritized a **complete, correct core** over a
screen for every bullet point. Specifically:

- **Reports screen (spec §24)** is not built as a separate screen. All the
  underlying data and filtering you'd need is already in the repositories
  (`AuditLogRepository.forWorker`, `.forTask`, date helpers in
  `DateFormatter.isToday/isThisWeek/isThisMonth`) — it needs a UI screen
  in `lib/features/reports/` that filters and aggregates using those, which
  I left as a clearly-scoped next step rather than rushing it.
- **Payments and Collections** don't have their own dedicated screens; the
  actions (Record Payment, Assign Collector, Complete Handover) are modal
  dialogs in `lib/features/allocations/allocation_dialogs.dart`, reachable
  from the Worksheet and Worker Detail. This matches the data model but
  not the literal "Payments" / "Collections" tab structure in §21 — easy
  to add as thin screens that just filter the same repositories.
- **Custom work types** — the data model and `CalculationCategory.customFormula`
  already support adding a new work type without code changes to the
  *calculation* logic, but there's no settings UI yet for the Boss to
  create one; today it requires adding a row to `WorkType.builtIns()`.
- **Login/roles UI** — `UserRole` exists and is recorded on every audit
  log, but there's no login screen; `AppState.currentUser` is fixed to a
  Boss account.

## Path to real multi-device realtime sync

Everything outside `lib/repositories/` depends only on the repository
classes' public methods (`getAll`, `getById`, `put`, `watchAll`), never on
Hive directly. To move to Firestore or Supabase for true cross-device live
updates:

1. Write new repository classes with the same method signatures, backed
   by `FirebaseFirestore` snapshots (`.snapshots()` naturally gives you a
   `Stream`, matching `watchAll()`) or Supabase's realtime channels.
2. Swap the constructors in `lib/state/app_state.dart`.
3. Nothing in `services/`, `features/`, or `models/` needs to change.

## Currency & formatting

All money is stored as whole Tanzanian Shillings (`int`). `CurrencyFormatter`
is the only place that formats money for display — change it there once
if you need a different currency symbol or grouping.
