import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A small generic wrapper around a Hive box that gives every repository
/// CRUD + a live stream of "all records" for free. Each concrete
/// repository just supplies `toMap`/`fromMap` for its model type.
///
/// This is also the seam that provides "live updates" within the running
/// app: every write goes through here, every write notifies the box's
/// listenable, and every screen that cares rebuilds automatically via
/// [watchAll]. True cross-device realtime would swap this class's
/// internals for a Firestore/Supabase stream without touching callers.
class BaseRepository<T> {
  BaseRepository(this.box, {required this.toMap, required this.fromMap});

  final Box box;
  final Map<String, dynamic> Function(T) toMap;
  final T Function(Map map) fromMap;

  T? getById(String id) {
    final raw = box.get(id);
    if (raw == null) return null;
    return fromMap(Map<String, dynamic>.from(raw as Map));
  }

  List<T> getAll() =>
      box.values.map((raw) => fromMap(Map<String, dynamic>.from(raw as Map))).toList();

  Future<void> put(String id, T value) => box.put(id, toMap(value));

  Future<void> delete(String id) => box.delete(id);

  /// Emits a fresh full list every time the underlying box changes.
  Stream<List<T>> watchAll() {
    late final StreamController<List<T>> controller;
    void emit() => controller.add(getAll());
    final sub = box.watch().listen((_) => emit());
    controller = StreamController<List<T>>.broadcast(
      onListen: emit,
      onCancel: () => sub.cancel(),
    );
    return controller.stream;
  }

  /// Listenable form, handy for [ValueListenableBuilder] where a Stream
  /// subscription would be overkill.
  ValueListenable<Box> listenable() => box.listenable();
}
