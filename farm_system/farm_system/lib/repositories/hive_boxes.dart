import 'package:hive_flutter/hive_flutter.dart';

/// Central place that names every Hive box and opens them once at startup.
/// Swapping the persistence layer later (e.g. to Firestore/Supabase for
/// true multi-device realtime sync) means rewriting the repositories in
/// this folder only — models, services and UI are untouched because they
/// only depend on the repository interfaces, not on Hive directly.
class HiveBoxes {
  HiveBoxes._();

  static const users = 'users';
  static const workers = 'workers';
  static const workTypes = 'work_types';
  static const tasks = 'tasks';
  static const calculations = 'calculations';
  static const allocations = 'allocations';
  static const adjustments = 'adjustments';
  static const payments = 'payments';
  static const collections = 'collections';
  static const handovers = 'handovers';
  static const auditLogs = 'audit_logs';

  static const all = [
    users,
    workers,
    workTypes,
    tasks,
    calculations,
    allocations,
    adjustments,
    payments,
    collections,
    handovers,
    auditLogs,
  ];

  static Future<void> openAll() async {
    for (final name in all) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name);
      }
    }
  }
}
