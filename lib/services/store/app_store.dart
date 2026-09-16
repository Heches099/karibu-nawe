import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/id_gen.dart';
import '../../models/allocation.dart';
import '../../models/audit_log.dart';
import '../../models/calculation.dart';
import '../../models/enums.dart';
import '../../models/payment.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../models/worker.dart';
import '../../models/work_type.dart';
import '../../models/work_progress.dart';
import '../../models/work_zone.dart';
import '../../repositories/backend/app_backend.dart';
import '../../services/audit/audit_service.dart';
import '../../services/calculation/calculation_engine.dart';
import '../../services/summary/summary_service.dart';

/// Convenience import path used by feature screens.
export '../../models/allocation.dart';
export '../../models/audit_log.dart';
export '../../models/calculation.dart';
export '../../models/enums.dart';
export '../../models/payment.dart';
export '../../models/task.dart';
export '../../models/user.dart';
export '../../models/worker.dart';
export '../../models/work_type.dart';
export '../../models/work_zone.dart';
export '../../models/work_progress.dart';

/// Central reactive state + persistence facade.
///
/// All mutations go through here. Each mutation:
///   1. validates the business rules,
///   2. writes to the persistent backend,
///   3. updates the in-memory lists,
///   4. appends the audit record,
///   5. notifies listeners so every open screen updates live.
class AppStore extends ChangeNotifier {
  final AppBackend backend;
  final SummaryService summary = const SummaryService();
  final AuditService audit = const AuditService();
  final WorkTypeCalculator calculator = WorkTypeCalculator.standard();

  AppStore(this.backend);

  bool _ready = false;
  bool get ready => _ready;

  List<User> users = [];
  List<Worker> workers = [];
  List<WorkType> workTypes = [];
  List<Task> tasks = [];
  List<Calculation> calculations = [];
  List<Allocation> allocations = [];
  List<AllocationAdjustment> adjustments = [];
  List<Payment> payments = [];
  List<Collection> collections = [];
  List<Handover> handovers = [];
  List<WorkZone> workZones = [];
  List<WorkProgress> workProgress = [];
  List<AuditLog> audits = [];

  User? session;
  String get actorName => session?.displayName ?? 'Manager';
  bool get isAdmin => session?.role == UserRole.boss || session?.role == UserRole.manager;

  void _requireAdmin(String action) {
    if (!isAdmin) {
      throw AuthorizationException('Only an authorized manager can $action.');
    }
  }

  /// Local backend is always available => live.
  bool get isConnected => true;

  /// Current theme mode (persisted).
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Generates a new id.
  String genId() => IdGen.newId();

  // ---------------------------------------------------------------- helpers
  Worker? workerById(String? id) {
    if (id == null) return null;
    for (final w in workers) {
      if (w.id == id) return w;
    }
    return null;
  }

  String workerName(String? id) => workerById(id)?.name ?? '—';

  Task? taskById(String? id) {
    if (id == null) return null;
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  String taskTitle(String? id) => taskById(id)?.title ?? '—';

  WorkType? workTypeById(String? id) {
    if (id == null) return null;
    for (final w in workTypes) {
      if (w.id == id) return w;
    }
    return null;
  }

  WorkType? workTypeOf(Task task) => workTypeById(task.workTypeId);

  Calculation? calculationFor(String taskId) {
    for (final c in calculations) {
      if (c.taskId == taskId) return c;
    }
    return null;
  }

  List<Allocation> allocationsFor(String taskId) =>
      allocations.where((a) => a.taskId == taskId).toList()
        ..sort((a, b) => workerName(a.workerId).compareTo(workerName(b.workerId)));

  double totalPaidFor({required String taskId, required String workerId}) {
    var t = 0.0;
    for (final p in payments) {
      if (p.taskId == taskId && p.workerId == workerId) t += p.amount;
    }
    return t;
  }

  Allocation? allocationFor({required String taskId, required String workerId}) {
    for (final a in allocations) {
      if (a.taskId == taskId && a.workerId == workerId) return a;
    }
    return null;
  }

  List<Payment> paymentsFor({required String taskId, String? workerId}) {
    final out = payments.where((p) => p.taskId == taskId);
    return (workerId == null ? out : out.where((p) => p.workerId == workerId))
        .toList()
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
  }

  List<AllocationAdjustment> adjustmentsFor(String allocationId, {String? workerId}) {
    final out = workerId == null
        ? adjustments.where((a) => a.allocationId == allocationId)
        : adjustments.where((a) => a.workerId == workerId);
    return out.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  PaymentStatus paymentStatusFor({required String taskId, required String workerId, required double allocated}) {
    final paid = totalPaidFor(taskId: taskId, workerId: workerId);
    return derivePaymentStatus(allocated, paid);
  }

  /// Collections where [collectorId] collects for another worker.
  List<Collection> collectionsByCollector(String collectorId, {String? taskId}) {
    final out = collections.where((c) => c.collectorId == collectorId);
    return (taskId == null ? out : out.where((c) => c.taskId == taskId)).toList()
      ..sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
  }

  List<Collection> collectionsForWorker(String workerId, {String? taskId}) {
    final out = collections.where((c) => c.workerId == workerId);
    return (taskId == null ? out : out.where((c) => c.taskId == taskId)).toList();
  }

  double handedOverBy(String collectorId) {
    var t = 0.0;
    for (final h in handovers) {
      if (h.collectorId == collectorId) t += h.amount;
    }
    return t;
  }

  double pendingHandoverBy(String collectorId) {
    var collected = 0.0;
    for (final c in collections) {
      if (c.collectorId == collectorId) collected += c.amount;
    }
    return collected - handedOverBy(collectorId);
  }

  double pendingHandoverForWorker({required String collectorId, required String workerId}) {
    var collected = 0.0;
    for (final c in collections) {
      if (c.collectorId == collectorId && c.workerId == workerId) collected += c.amount;
    }
    var handed = 0.0;
    for (final h in handovers) {
      if (h.collectorId == collectorId && h.workerId == workerId) handed += h.amount;
    }
    return collected - handed;
  }

  bool hasHandoverFor({required String collectorId, required String workerId}) =>
      handovers.any((h) => h.collectorId == collectorId && h.workerId == workerId);

  // ---------------------------------------------------------------- load / seed
  Future<void> init() async {
    await _loadAll();
    await _ensureDefaults();
    await _restoreSession();
    await _loadThemeMode();
    _ready = true;
    notifyListeners();
  }

  Future<void> _loadAll() async {
    users = (await backend.getAll(DbStore.users)).map(User.fromMap).toList();
    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    workers = (await backend.getAll(DbStore.workers)).map(Worker.fromMap).toList();
    workers.sort((a, b) => a.name.compareTo(b.name));
    workTypes = (await backend.getAll(DbStore.workTypes)).map(WorkType.fromMap).toList();
    workTypes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    tasks = (await backend.getAll(DbStore.tasks)).map(Task.fromMap).toList();
    tasks.sort((a, b) => b.workDate.compareTo(a.workDate));
    calculations = (await backend.getAll(DbStore.calculations)).map(Calculation.fromMap).toList();
    allocations = (await backend.getAll(DbStore.allocations)).map(Allocation.fromMap).toList();
    adjustments = (await backend.getAll(DbStore.allocationAdjustments))
        .map(AllocationAdjustment.fromMap)
        .toList();
    payments = (await backend.getAll(DbStore.payments)).map(Payment.fromMap).toList();
    payments.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    collections = (await backend.getAll(DbStore.collections)).map(Collection.fromMap).toList();
    collections.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
    handovers = (await backend.getAll(DbStore.handovers)).map(Handover.fromMap).toList();
    handovers.sort((a, b) => b.handedAt.compareTo(a.handedAt));
    workZones = (await backend.getAll(DbStore.workZones)).map(WorkZone.fromMap).toList();
    workZones.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    workProgress = (await backend.getAll(DbStore.workProgress)).map(WorkProgress.fromMap).toList();
    workProgress.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    audits = (await backend.getAll(DbStore.auditLogs)).map(AuditLog.fromMap).toList();
    audits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _ensureDefaults() async {
    if (users.isEmpty) {
      final boss = User(
        id: IdGen.newId(),
        username: 'boss',
        password: '1234',
        displayName: 'Boss',
        role: UserRole.boss,
        createdAt: DateTime.now(),
      );
      users.add(boss);
      await backend.put(DbStore.users, boss.id, boss.toMap());
    }
    if (workTypes.isEmpty) {
      await _seedBuiltInWorkTypes();
    }
  }

  Future<void> _seedBuiltInWorkTypes() async {
    final now = DateTime.now();
    final defs = <WorkType>[
      WorkType(id: 'wt_kupalilia', name: 'Kupalilia', code: 'Kupalilia', description: 'Weeding', formulaCode: 'area_fixed', fields: WorkType.kupalaFields, sortOrder: 1, createdAt: now),
      WorkType(id: 'wt_kupanda', name: 'Kupanda', code: 'Kupanda', description: 'Planting', formulaCode: 'area_rate', fields: WorkType.kupandaFields, sortOrder: 2, createdAt: now),
      WorkType(id: 'wt_kupiga_dawa', name: 'Kupiga Dawa', code: 'Kupiga Dawa', description: 'Spraying', formulaCode: 'kupiga_dawa', fields: WorkType.kupigaDawaFields, sortOrder: 3, createdAt: now),
      WorkType(id: 'wt_kuvuna', name: 'Kuvuna', code: 'Kuvuna', description: 'Harvesting', formulaCode: 'quantity_price', fields: WorkType.kuvunaFields, sortOrder: 4, createdAt: now),
      WorkType(id: 'wt_mbolea', name: 'Mbolea', code: 'Mbolea', description: 'Fertiliser application', formulaCode: 'quantity_price', fields: WorkType.mboleaFields, sortOrder: 5, createdAt: now),
    ];
    for (final wt in defs) {
      workTypes.add(wt);
      await backend.put(DbStore.workTypes, wt.id, wt.toMap());
    }
  }

  WorkType addWorkType({required String name, String? description, String calculationMode = 'quantity'}) {
    _requireAdmin('manage work types');
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ValidationException('Work type name is required.');
    if (workTypes.any((w) => w.name.toLowerCase() == cleanName.toLowerCase())) {
      throw ValidationException('A work type with this name already exists.');
    }
    final now = DateTime.now();
    final areaBased = calculationMode == 'area';
    final workType = WorkType(
      id: IdGen.newId(),
      name: cleanName,
      code: 'custom_${IdGen.newId()}',
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      formulaCode: areaBased ? 'area_rate' : 'custom',
      fields: areaBased ? WorkType.customAreaFields : WorkType.customFields,
      sortOrder: workTypes.length + 1,
      isBuiltIn: false,
      createdAt: now,
    );
    workTypes.add(workType);
    workTypes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _persist(DbStore.workTypes, workType.id, workType.toMap());
    _recordAudit(AuditLog.create(
      action: AuditActionType.settingsUpdated,
      actor: actorName,
      newValue: {'workTypeId': workType.id, 'name': workType.name},
    ));
    notifyListeners();
    return workType;
  }

  Future<void> _restoreSession() async {
    final meta = await backend.get(DbStore.meta, 'session');
    if (meta == null) return;
    final id = meta['sessionUserId'] as String?;
    if (id == null) return;
    for (final u in users) {
      if (u.id == id) session = u;
    }
  }

  Future<void> _loadThemeMode() async {
    final meta = await backend.get(DbStore.meta, 'themeMode');
    if (meta != null) {
      final index = meta['mode'] as int?;
      if (index != null && index >= 0 && index < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[index];
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await backend.put(DbStore.meta, 'themeMode', {'mode': mode.index});
    notifyListeners();
  }

  WorkZone addWorkZone({
    required String name,
    required Task task,
    required double areaSquareMeters,
    List<Map<String, double>> boundary = const [],
    double? accuracyMeters,
  }) {
    if (name.trim().isEmpty) throw ValidationException('Work zone name is required.');
    if (areaSquareMeters <= 0) throw ValidationException('Work zone area must be greater than zero.');
    final now = DateTime.now();
    final zone = WorkZone(
      id: IdGen.newId(),
      name: name.trim(),
      taskId: task.id,
      areaSquareMeters: areaSquareMeters,
      boundary: boundary,
      accuracyMeters: accuracyMeters,
      createdBy: actorName,
      createdAt: now,
      updatedAt: now,
    );
    workZones.insert(0, zone);
    _persist(DbStore.workZones, zone.id, zone.toMap());
    _recordAudit(AuditLog.create(
      action: AuditActionType.workZoneCreated,
      actor: actorName,
      taskId: task.id,
      newValue: {'zoneId': zone.id, 'name': zone.name, 'areaSquareMeters': areaSquareMeters},
    ));
    notifyListeners();
    return zone;
  }

  List<WorkProgress> progressForZone(String zoneId) =>
      workProgress.where((p) => p.workZoneId == zoneId).toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

  WorkProgress recordWorkProgress({
    required WorkZone zone,
    required double completedSquareMeters,
    required ProgressStatus status,
    String? workerId,
    String? evidenceNote,
  }) {
    if (completedSquareMeters < 0 || completedSquareMeters > zone.areaSquareMeters + 0.001) {
      throw ValidationException('Completed area must be between zero and the assigned zone area.');
    }
    final progress = WorkProgress(
      id: IdGen.newId(),
      workZoneId: zone.id,
      assignedSquareMeters: zone.areaSquareMeters,
      completedSquareMeters: completedSquareMeters,
      status: status,
      workerId: workerId,
      evidenceNote: evidenceNote,
      recordedAt: DateTime.now(),
      recordedBy: actorName,
    );
    workProgress.insert(0, progress);
    _persist(DbStore.workProgress, progress.id, progress.toMap());
    _recordAudit(AuditLog.create(
      action: AuditActionType.workProgressUpdated,
      actor: actorName,
      taskId: zone.taskId,
      workerId: workerId,
      newValue: {
        'workZoneId': zone.id,
        'assignedSquareMeters': zone.areaSquareMeters,
        'completedSquareMeters': completedSquareMeters,
        'status': status.name,
      },
    ));
    notifyListeners();
    return progress;
  }

  Future<void> _putSession() => backend.put(DbStore.meta, 'session', {'sessionUserId': session?.id ?? ''});

  // ---------------------------------------------------------------- auth
  Future<User?> login(String username, String password) async {
    final u = users.where((x) => x.username == username.trim()).firstOrNull;
    if (u == null || u.password != password) {
      throw ValidationException('Invalid username or password.');
    }
    if (!u.isActive) {
      throw ValidationException('This account is disabled.');
    }
    session = u;
    await _putSession();
    audits.insert(0, audit.login(actor: u.displayName));
    await backend.put(DbStore.auditLogs, audits.first.id, audits.first.toMap());
    notifyListeners();
    return u;
  }

  Future<void> logout() async {
    session = null;
    await backend.put(DbStore.meta, 'session', {'sessionUserId': ''});
    notifyListeners();
  }

  User? getCurrentUser() => session;

  // ---------------------------------------------------------------- workers
  Worker addWorker({required String name, String phone = '', String? field, String? notes}) {
    _requireAdmin('add workers');
    name = name.trim();
    if (name.isEmpty) throw ValidationException('Worker name is required.');
    final w = Worker(
      id: IdGen.newId(),
      name: name,
      phone: phone.trim(),
      field: field,
      notes: notes,
      createdAt: DateTime.now(),
    );
    workers.add(w);
    workers.sort((a, b) => a.name.compareTo(b.name));
    _persist(DbStore.workers, w.id, w.toMap());
    final log = audit.workerAdded(actor: actorName, workerId: w.id, name: w.name);
    _recordAudit(log);
    notifyListeners();
    return w;
  }

  Worker updateWorker(Worker worker, {String? name, String? phone, String? field, String? notes, bool? isActive}) {
    final updated = Worker(
      id: worker.id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : worker.name,
      phone: phone ?? worker.phone,
      field: field ?? worker.field,
      notes: notes ?? worker.notes,
      isActive: isActive ?? worker.isActive,
      createdAt: worker.createdAt,
    );
    final ix = workers.indexWhere((w) => w.id == worker.id);
    if (ix == -1) throw NotFoundException('Worker not found.');
    workers[ix] = updated;
    _persist(DbStore.workers, updated.id, updated.toMap());
    notifyListeners();
    return updated;
  }

  // ---------------------------------------------------------------- tasks
  Task createTask({
    required String title,
    required String description,
    required WorkType workType,
    required DateTime workDate,
    required String field,
    String? notes,
  }) {
    _requireAdmin('create tasks');
    title = title.trim();
    field = field.trim();
    if (title.isEmpty) throw ValidationException('Task title is required.');
    if (field.isEmpty) throw ValidationException('Field / farm location is required.');
    final t = Task(
      id: IdGen.newId(),
      title: title,
      description: description.trim(),
      workTypeId: workType.id,
      workDate: workDate,
      field: field,
      notes: notes?.trim(),
      status: TaskStatus.active,
      createdBy: actorName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    tasks.insert(0, t);
    tasks.sort((a, b) => b.workDate.compareTo(a.workDate));
    _persist(DbStore.tasks, t.id, t.toMap());
    final log = audit.taskCreated(actor: actorName, taskId: t.id, title: t.title);
    _recordAudit(log);
    notifyListeners();
    return t;
  }

  Task updateTaskStatus(String taskId, TaskStatus status) {
    final ix = tasks.indexWhere((t) => t.id == taskId);
    if (ix == -1) throw NotFoundException('Task not found.');
    final current = tasks[ix];
    final updated = current.copyWith(status: status);
    tasks[ix] = updated;
    _persist(DbStore.tasks, updated.id, updated.toMap());
    notifyListeners();
    return updated;
  }

  void deleteTask(String taskId) {
    if (allocations.any((a) => a.taskId == taskId)) {
      throw ValidationException('Cannot delete a task that already has worker allocations. The history must be preserved.');
    }
    final removed = calculations.where((c) => c.taskId == taskId).toList();
    tasks.removeWhere((t) => t.id == taskId);
    calculations.removeWhere((c) => c.taskId == taskId);
    backend.remove(DbStore.tasks, taskId);
    for (final c in removed) {
      backend.remove(DbStore.calculations, c.id);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- calculation
  /// Runs the calculation engine, saves the result as the official baseline
  /// and (optionally) creates allocations for the supplied workers in one go.
  Future<Calculation> saveCalculation({
    required Task task,
    required WorkType workType,
    required Map<String, dynamic> inputs,
  }) async {
    _requireAdmin('save calculations');
    final result = calculator.computeForWorkType(workType, inputs);
    if (calculations.any((c) => c.taskId == task.id)) {
      throw ValidationException('This task already has a saved calculation. The baseline cannot be overwritten.');
    }
    final existingByWorker = allocations.where((a) => a.taskId == task.id).length;
    if (existingByWorker > 0) {
      throw ValidationException('Cannot re-run the calculator after workers have been allocated. The original calculation is the baseline.');
    }
    final calc = Calculation(
      id: IdGen.newId(),
      taskId: task.id,
      workTypeId: workType.id,
      inputs: result.inputs,
      outputs: result.outputs,
      expectedAmount: result.expectedAmount,
      resourceCost: result.resourceCost,
      formulaLabel: result.formulaLabel,
      createdBy: actorName,
      createdAt: DateTime.now(),
    );
    calculations.add(calc);
    _persist(DbStore.calculations, calc.id, calc.toMap());
    final log = audit.calculationSaved(
      actor: actorName,
      taskId: task.id,
      expectedAmount: calc.expectedAmount,
      outputs: calc.outputs,
    );
    _recordAudit(log);
    notifyListeners();
    return calc;
  }

  // ---------------------------------------------------------------- allocations
  Allocation addAllocation({
    required Task task,
    required Worker worker,
    required double expectedAmount,
    double? allocatedAmount,
    String? reason,
    String? notes,
  }) {
    _requireAdmin('allocate worker payments');
    final allocated = allocatedAmount ?? expectedAmount;
    if (allocated < 0) throw ValidationException('Allocated amount cannot be negative.');
    if ((allocated - expectedAmount).abs() > 0.001 &&
        (reason == null || reason.trim().isEmpty)) {
      throw ValidationException('A reason is required when the allocated amount differs from the expected amount.');
    }
    final existing = allocationFor(taskId: task.id, workerId: worker.id);
    if (existing != null) {
      throw ValidationException('${worker.name} is already allocated on this task.');
    }
    final allocation = Allocation(
      id: IdGen.newId(),
      taskId: task.id,
      workerId: worker.id,
      expectedAmount: expectedAmount,
      allocatedAmount: allocated,
      notes: notes,
      createdBy: actorName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    allocations.add(allocation);
    _persist(DbStore.allocations, allocation.id, allocation.toMap());

    final hasAdjustment = (allocated - expectedAmount).abs() > 0.001;
    if (hasAdjustment) {
      final adj = AllocationAdjustment(
        id: IdGen.newId(),
        allocationId: allocation.id,
        taskId: task.id,
        workerId: worker.id,
        fromAmount: expectedAmount,
        toAmount: allocated,
        reason: reason!.trim(),
        changedBy: actorName,
        createdAt: DateTime.now(),
      );
      adjustments.add(adj);
      _persist(DbStore.allocationAdjustments, adj.id, adj.toMap());
      final log = audit.allocationModified(
        actor: actorName,
        taskId: task.id,
        workerId: worker.id,
        allocationId: allocation.id,
        fromAmount: expectedAmount,
        toAmount: allocated,
        reason: reason,
      );
      _recordAudit(log);
    } else {
      final log = audit.allocationCreated(
        actor: actorName,
        taskId: task.id,
        workerId: worker.id,
        allocationId: allocation.id,
        expectedAmount: expectedAmount,
        allocatedAmount: allocated,
      );
      _recordAudit(log);
    }
    notifyListeners();
    return allocation;
  }

  /// Changes an allocation and records an adjustment with a mandatory reason.
  Allocation adjustAllocation({
    required String allocationId,
    required double newAmount,
    required String reason,
  }) {
    _requireAdmin('adjust worker allocations');
    if (newAmount < 0) throw ValidationException('Allocated amount cannot be negative.');
    final ix = allocations.indexWhere((a) => a.id == allocationId);
    if (ix == -1) throw NotFoundException('Allocation not found.');
    final current = allocations[ix];
    if ((newAmount - current.allocatedAmount).abs() < 0.001) {
      throw ValidationException('The new amount is the same as the current allocation.');
    }
    final isEmptyReason = reason.trim().isEmpty;
    if (isEmptyReason) {
      throw ValidationException('A reason is required for every allocation change.');
    }
    final adj = AllocationAdjustment(
      id: IdGen.newId(),
      allocationId: allocationId,
      taskId: current.taskId,
      workerId: current.workerId,
      fromAmount: current.allocatedAmount,
      toAmount: newAmount,
      reason: reason.trim(),
      changedBy: actorName,
      createdAt: DateTime.now(),
    );
    adjustments.add(adj);
    _persist(DbStore.allocationAdjustments, adj.id, adj.toMap());

    final updated = Allocation(
      id: current.id,
      taskId: current.taskId,
      workerId: current.workerId,
      expectedAmount: current.expectedAmount,
      allocatedAmount: newAmount,
      notes: current.notes,
      createdBy: current.createdBy,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    allocations[ix] = updated;
    _persist(DbStore.allocations, updated.id, updated.toMap());

    final log = audit.allocationModified(
      actor: actorName,
      taskId: current.taskId,
      workerId: current.workerId,
      allocationId: allocationId,
      fromAmount: current.allocatedAmount,
      toAmount: newAmount,
      reason: reason,
    );
    _recordAudit(log);
    notifyListeners();
    return updated;
  }

  // ---------------------------------------------------------------- payments
  Future<Payment> addPayment({
    required Task task,
    required Worker worker,
    required double amount,
    DateTime? paidAt,
    String method = '',
    String? note,
    Worker? collectedBy,
  }) async {
    _requireAdmin('record payments');
    if (amount <= 0) throw ValidationException('Payment must be greater than zero.');
    final allocation = allocationFor(taskId: task.id, workerId: worker.id);
    if (allocation == null) {
      throw ValidationException('Add an allocation for ${worker.name} before recording a payment.');
    }
    final alreadyPaid = totalPaidFor(taskId: task.id, workerId: worker.id);
    final remaining = allocation.allocatedAmount - alreadyPaid;
    if (amount > remaining + 0.001) {
      throw ValidationException('Payment of ${_fmtMoney(amount)} exceeds the remaining TSh ${remaining.round()} for ${worker.name}.');
    }
    final when = paidAt ?? DateTime.now();
    final duplicate = payments.any((p) =>
        p.taskId == task.id &&
        p.workerId == worker.id &&
        (p.amount - amount).abs() < 0.001 &&
        (p.paidAt.difference(when).inMinutes.abs() < 2));
    if (duplicate) {
      throw ValidationException('A payment with the same amount was already recorded at the same time. Refuse to save duplicates.');
    }
    if (collectedBy != null && collectedBy.id == worker.id) collectedBy = null;

    final payment = Payment(
      id: IdGen.newId(),
      taskId: task.id,
      workerId: worker.id,
      allocationId: allocation.id,
      amount: amount,
      paidAt: when,
      method: method,
      note: note,
      recordedBy: actorName,
      createdAt: DateTime.now(),
    );
    payments.insert(0, payment);
    _persist(DbStore.payments, payment.id, payment.toMap());
    _recordAudit(audit.paymentCreated(
      actor: actorName,
      taskId: task.id,
      workerId: worker.id,
      paymentId: payment.id,
      amount: amount,
    ));

    if (collectedBy != null) {
      final collection = Collection(
        id: IdGen.newId(),
        taskId: task.id,
        workerId: worker.id,
        collectorId: collectedBy.id,
        amount: amount,
        collectedAt: when,
        note: note,
        recordedBy: actorName,
        createdAt: DateTime.now(),
      );
      collections.insert(0, collection);
      _persist(DbStore.collections, collection.id, collection.toMap());
      _recordAudit(audit.collectorAssigned(
        actor: actorName,
        taskId: task.id,
        collectorId: collectedBy.id,
        workerId: worker.id,
      ));
      _recordAudit(audit.collectionCreated(
        actor: actorName,
        taskId: task.id,
        workerId: worker.id,
        collectorId: collectedBy.id,
        collectionId: collection.id,
        amount: amount,
      ));
    }
    notifyListeners();
    return payment;
  }

  /// Pays the full remaining allocation without asking the manager to retype
  /// an amount. This is the normal worker-sheet payment action.
  Future<Payment> payAllocation({required Task task, required Worker worker}) async {
    final allocation = allocationFor(taskId: task.id, workerId: worker.id);
    if (allocation == null) {
      throw ValidationException('Add an allocation for ${worker.name} before recording a payment.');
    }
    final remaining = allocation.allocatedAmount - totalPaidFor(taskId: task.id, workerId: worker.id);
    if (remaining <= 0.001) {
      throw ValidationException('${worker.name} is already fully paid.');
    }
    return addPayment(task: task, worker: worker, amount: remaining);
  }

  /// Settles a worker and links the money to a collector in one action.
  Future<Payment> recordCollection({
    required Task task,
    required Worker worker,
    required Worker collector,
    required double amount,
    DateTime? collectedAt,
    String? note,
  }) async {
    if (collector.id == worker.id) {
      throw ValidationException('A worker cannot collect for themselves.');
    }
    if (amount <= 0) throw ValidationException('Collection amount must be greater than zero.');
    if (allocationFor(taskId: task.id, workerId: worker.id) == null) {
      throw ValidationException('Add an allocation for ${worker.name} first.');
    }
    if (collections.any((c) =>
        c.taskId == task.id &&
        c.workerId == worker.id &&
        c.collectorId == collector.id &&
        (c.amount - amount).abs() < 0.001)) {
      throw ValidationException('A collection for this worker, collector and amount already exists.');
    }
    return addPayment(
      task: task,
      worker: worker,
      amount: amount,
      paidAt: collectedAt,
      note: note,
      collectedBy: collector,
    );
  }

  // ---------------------------------------------------------------- handover
  Future<Handover> addHandover({
    required Worker collector,
    required Worker receivedBy,
    Task? task,
    required double amount,
    DateTime? handedAt,
    String? note,
  }) async {
    _requireAdmin('record handovers');
    if (amount <= 0) throw ValidationException('Handover amount must be greater than zero.');
    double collectedFor = 0;
    double handedFor = 0;
    for (final c in collections) {
      if (c.collectorId == collector.id && c.workerId == receivedBy.id) collectedFor += c.amount;
    }
    for (final h in handovers) {
      if (h.collectorId == collector.id && h.workerId == receivedBy.id) handedFor += h.amount;
    }
    final pendingForWorker = collectedFor - handedFor;
    if (amount > pendingForWorker + 0.001) {
      throw ValidationException('Amount exceeds the ${receivedBy.name} money still pending handover (TSh ${pendingForWorker.round()}).');
    }
    final h = Handover(
      id: IdGen.newId(),
      collectorId: collector.id,
      workerId: receivedBy.id,
      taskId: task?.id,
      amount: amount,
      handedAt: handedAt ?? DateTime.now(),
      receivedByWorkerId: receivedBy.id,
      note: note,
      recordedBy: actorName,
      createdAt: DateTime.now(),
    );
    handovers.insert(0, h);
    _persist(DbStore.handovers, h.id, h.toMap());
    _recordAudit(audit.handoverCompleted(
      actor: actorName,
      taskId: task?.id ?? '',
      workerId: receivedBy.id,
      collectorId: collector.id,
      handoverId: h.id,
      amount: amount,
    ));
    notifyListeners();
    return h;
  }

  // ---------------------------------------------------------------- seed demo
  Future<void> clearOperationalData() async {
    await backend.clearAll();
    users.clear();
    workers.clear();
    workTypes.clear();
    tasks.clear();
    calculations.clear();
    allocations.clear();
    adjustments.clear();
    payments.clear();
    collections.clear();
    handovers.clear();
    workZones.clear();
    workProgress.clear();
    audits.clear();
    await _ensureDefaults();
    _ready = true;
    notifyListeners();
  }

  Future<void> seedDemoData() async {
    if (workTypes.isEmpty) await _seedBuiltInWorkTypes();
    final kupalilia = workTypeById('wt_kupalilia')!;
    final dawa = workTypeById('wt_kupiga_dawa')!;
    final kupanda = workTypeById('wt_kupanda')!;
    final kuvuna = workTypeById('wt_kuvuna')!;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Future<Worker> wk(String name) async {
      final worker = Worker(id: IdGen.newId(), name: name, phone: '', createdAt: now.subtract(Duration(days: 30)));
      workers.add(worker);
      await backend.put(DbStore.workers, worker.id, worker.toMap());
      return worker;
    }

    final juma = await wk('Juma');
    final musa = await wk('Musa');
    final ali = await wk('Ali');
    final asha = await wk('Asha');
    final john = await wk('John');
    final neema = await wk('Neema');
    final rashidi = await wk('Rashidi');

    Task makeTask({
      required String title,
      required String description,
      required WorkType wt,
      required String field,
      int daysAgo = 0,
    }) {
      final t = Task(
        id: IdGen.newId(),
        title: title,
        description: description,
        workTypeId: wt.id,
        workDate: today.subtract(Duration(days: daysAgo)),
        field: field,
        status: TaskStatus.active,
        createdBy: 'Boss',
        createdAt: today.subtract(Duration(days: daysAgo + 2)),
        updatedAt: today.subtract(Duration(days: daysAgo + 1)),
      );
      tasks.add(t);
      return t;
    }

    void saveCalc(Task t, WorkType wt, Map<String, dynamic> inputs, Map<String, dynamic> outputs, double expected, String label, {double resourceCost = 0}) {
      final c = Calculation(id: IdGen.newId(), taskId: t.id, workTypeId: wt.id, inputs: inputs, outputs: outputs, expectedAmount: expected, resourceCost: resourceCost, formulaLabel: label, createdBy: 'Boss', createdAt: today.subtract(Duration(days: 1)));
      calculations.add(c);
      backend.put(DbStore.calculations, c.id, c.toMap());
    }

    Allocation addAlloc(Task t, Worker w, double expected, double allocated, {String? reason}) {
      final a = Allocation(
        id: IdGen.newId(),
        taskId: t.id,
        workerId: w.id,
        expectedAmount: expected,
        allocatedAmount: allocated,
        createdBy: 'Boss',
        createdAt: today.subtract(Duration(days: 1)),
        updatedAt: today.subtract(Duration(days: 1)),
      );
      allocations.add(a);
      backend.put(DbStore.allocations, a.id, a.toMap());
      if (reason != null) {
        final adj = AllocationAdjustment(id: IdGen.newId(), allocationId: a.id, taskId: t.id, workerId: w.id, fromAmount: expected, toAmount: allocated, reason: reason, changedBy: 'Boss', createdAt: a.createdAt);
        adjustments.add(adj);
        backend.put(DbStore.allocationAdjustments, adj.id, adj.toMap());
      }
      return a;
    }

    // Task 1 - Kupalilia Shamba A (today) - full/partial payments
    final t1 = makeTask(title: 'Kupalilia Shamba la Mashariki', description: 'Kupalilia sehemu ya mashariki ya shamba.', wt: kupalilia, field: 'Mashariki');
    saveCalc(t1, kupalilia, {'length': 30, 'width': 30, 'agreedPayment': 4000}, {'area': 900.0, 'agreedPayment': 4000.0}, 4000, 'Agreed payment for 900 m²');
    addAlloc(t1, juma, 4000, 4000);
    addAlloc(t1, musa, 4000, 4500, reason: 'Musa completed an additional section.');
    addAlloc(t1, ali, 4000, 4000);
    _seedPayment(t1, juma, 4000, today, 'Cash');
    _seedPayment(t1, musa, 4500, today, 'Cash');
    _seedPayment(t1, ali, 2000, today, 'Cash');
    _seedCollection(t1, musa, ali, 2000, today);

    // Task 2 - Kupiga Dawa Shamba B (yesterday)
    final t2 = makeTask(title: 'Kupiga Dawa Shamba B', description: 'Spraying against pests.', wt: dawa, field: 'Kusini', daysAgo: 1);
    const dawaWorkerPayment = 4000.0;
    const dawaResourceCost = 7200.0;
    saveCalc(
      t2,
      dawa,
      {'length': 30, 'width': 30, 'coverage': 1000, 'pricePerLitre': 8000, 'workerPayment': dawaWorkerPayment},
      {'area': 900.0, 'coverage': 1000.0, 'litres': 0.9, 'resourceCost': dawaResourceCost, 'workerPayment': dawaWorkerPayment},
      dawaWorkerPayment,
      '900 m² ÷ 1000 m²/L; worker pay TSh 4,000',
      resourceCost: dawaResourceCost,
    );
    final dawaExpected = dawaWorkerPayment;
    addAlloc(t2, asha, dawaExpected, dawaExpected);
    addAlloc(t2, john, dawaExpected, dawaExpected);
    addAlloc(t2, neema, dawaExpected, 7000, reason: 'Final measurement correction.');
    _seedPayment(t2, asha, 5000, today.subtract(const Duration(days: 1)), 'Cash');
    _seedPayment(t2, john, 4000, today.subtract(const Duration(days: 1)), 'Cash');
    _seedCollection(t2, musa, john, 4000, today.subtract(const Duration(days: 1)));
    _seedPayment(t2, neema, 3000, today.subtract(const Duration(days: 1)), 'Cash');

    // Task 3 - Kupanda Shamba C (2 days ago)
    final t3 = makeTask(title: 'Kupanda Shamba C', description: 'Kupanda mbegu mpya.', wt: kupanda, field: 'Kaskazini', daysAgo: 2);
    saveCalc(t3, kupanda, {'length': 40, 'width': 25, 'ratePerUnit': 10}, {'area': 1000.0, 'ratePerUnit': 10.0}, 10000, '1000 m² × TSh 10/m²');
    addAlloc(t3, juma, 10000, 10000);
    addAlloc(t3, asha, 10000, 10000);
    addAlloc(t3, musa, 10000, 9500, reason: 'Part of the assigned rows were not finished.');
    _seedPayment(t3, juma, 10000, today.subtract(const Duration(days: 2)), 'Cash');
    _seedPayment(t3, asha, 10000, today.subtract(const Duration(days: 2)), 'Cash');
    _seedPayment(t3, musa, 5000, today.subtract(const Duration(days: 2)), 'Cash');
    _seedCollection(t3, musa, asha, 10000, today.subtract(const Duration(days: 2)));
    _seedCollection(t3, musa, juma, 10000, today.subtract(const Duration(days: 2)));

    // Task 4 - Kuvuna Shamba D (3 days ago) with a completed handover
    final t4 = makeTask(title: 'Kuvuna Shamba D', description: 'Harvesting maize.', wt: kuvuna, field: 'Magharibi', daysAgo: 3);
    saveCalc(t4, kuvuna, {'harvestedKg': 2000, 'pricePerKg': 200}, {'harvestedKg': 2000.0, 'pricePerKg': 200.0}, 400000, '2000 × TSh 200');
    addAlloc(t4, ali, 400000, 400000);
    addAlloc(t4, rashidi, 400000, 400000);
    // partials + big collector
    _seedPayment(t4, ali, 200000, today.subtract(const Duration(days: 3)), 'Cash');
    _seedPayment(t4, rashidi, 150000, today.subtract(const Duration(days: 3)), 'Cash');
    _seedCollection(t4, musa, ali, 200000, today.subtract(const Duration(days: 3)));
    _seedHandover(musa, ali, 120000, today.subtract(const Duration(days: 2)), t4);
  }

  Future<void> _seedPayment(Task t, Worker w, double amount, DateTime at, String method) async {
    final p = Payment(id: IdGen.newId(), taskId: t.id, workerId: w.id, allocationId: allocationFor(taskId: t.id, workerId: w.id)?.id, amount: amount, paidAt: at, method: method, recordedBy: 'Boss', createdAt: at);
    payments.add(p);
    await backend.put(DbStore.payments, p.id, p.toMap());
  }

  Future<void> _seedCollection(Task t, Worker collector, Worker forWhom, double amount, DateTime at) async {
    final c = Collection(id: IdGen.newId(), taskId: t.id, workerId: forWhom.id, collectorId: collector.id, amount: amount, collectedAt: at, recordedBy: 'Boss', createdAt: at);
    collections.add(c);
    await backend.put(DbStore.collections, c.id, c.toMap());
  }

  Future<void> _seedHandover(Worker collector, Worker receivedBy, double amount, DateTime at, Task? task) async {
    final h = Handover(id: IdGen.newId(), collectorId: collector.id, workerId: receivedBy.id, taskId: task?.id, amount: amount, handedAt: at, receivedByWorkerId: receivedBy.id, recordedBy: 'Boss', createdAt: at);
    handovers.add(h);
    await backend.put(DbStore.handovers, h.id, h.toMap());
  }

  // ---------------------------------------------------------------- audit
  Future<void> _recordAudit(AuditLog log) async {
    audits.insert(0, log);
    try {
      await backend.put(DbStore.auditLogs, log.id, log.toMap());
    } catch (_) {
      // audit is append-only best effort on local backend
    }
  }

  Future<void> _persist(String store, String id, Map<String, dynamic> map) async {
    await backend.put(store, id, map);
  }
}

String _fmtMoney(num v) => 'TSh ${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

extension FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}