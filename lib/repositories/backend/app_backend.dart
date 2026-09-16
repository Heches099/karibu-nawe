import 'package:sembast/sembast.dart';

import '../../core/db/app_database.dart' show openAppDatabase;
import '../../core/errors/app_exception.dart';

/// Collection (store) names inside the local persistent database.
abstract class DbStore {
  DbStore._();

  static const users = 'users';
  static const workTypes = 'work_types';
  static const workers = 'workers';
  static const tasks = 'tasks';
  static const calculations = 'calculations';
  static const allocations = 'allocations';
  static const allocationAdjustments = 'allocation_adjustments';
  static const payments = 'payments';
  static const collections = 'collections';
  static const handovers = 'handovers';
  static const workZones = 'work_zones';
  static const workProgress = 'work_progress';
  static const auditLogs = 'audit_logs';
  static const meta = 'meta';
}

/// Low level persistence wrapper around sembast.
///
/// Every read/write goes through this class so a remote backend (e.g.
/// Firestore / Supabase) can be plugged in later without touching the app.
class AppBackend {
  final Database _db;
  AppBackend(this._db);

  static Future<AppBackend> open() async {
    try {
      final db = await openAppDatabase();
      return AppBackend(db);
    } catch (e) {
      throw StorageException('Failed to open the database.', cause: e);
    }
  }

  StoreRef<String, Map<String, Object?>> _store(String name) =>
      StoreRef<String, Map<String, Object?>>(name);

  Future<void> put(String storeName, String id, Map<String, dynamic> value) async {
    try {
      await _store(storeName).record(id).put(_db, value);
    } catch (e) {
      throw StorageException('Failed to save record to $storeName.', cause: e);
    }
  }

  Future<void> remove(String storeName, String id) async {
    try {
      await _store(storeName).record(id).delete(_db);
    } catch (e) {
      throw StorageException('Failed to delete record from $storeName.', cause: e);
    }
  }

  Future<Map<String, dynamic>?> get(String storeName, String id) async {
    final rec = await _store(storeName).record(id).get(_db);
    return rec == null ? null : Map<String, dynamic>.from(rec);
  }

  Future<List<Map<String, dynamic>>> getAll(String storeName) async {
    final records = await _store(storeName).find(_db);
    final out = <Map<String, dynamic>>[];
    for (final r in records) {
      final v = r.value;
      out.add(Map<String, dynamic>.from(v));
    }
    out.sort((a, b) {
      final ka = a['id'] as String? ?? '';
      final kb = b['id'] as String? ?? '';
      return ka.compareTo(kb);
    });
    return out;
  }

  Future<void> clear(String storeName) async {
    try {
      await _store(storeName).delete(_db);
    } catch (e) {
      throw StorageException('Failed to clear $storeName.', cause: e);
    }
  }

  Future<void> clearAll() async {
    for (final store in _allStores) {
      await clear(store);
    }
  }

  static const List<String> _allStores = [
    DbStore.users,
    DbStore.workTypes,
    DbStore.workers,
    DbStore.tasks,
    DbStore.calculations,
    DbStore.allocations,
    DbStore.allocationAdjustments,
    DbStore.payments,
    DbStore.collections,
    DbStore.handovers,
    DbStore.workZones,
    DbStore.workProgress,
    DbStore.auditLogs,
    DbStore.meta,
  ];

  static List<String> get allStores => _allStores;
}