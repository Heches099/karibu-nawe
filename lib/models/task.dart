import 'enums.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final String workTypeId;
  final DateTime workDate;
  final String field;
  final String? notes;
  final TaskStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.workTypeId,
    required this.workDate,
    required this.field,
    this.notes,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.create({
    required String title,
    required String description,
    required String workTypeId,
    required DateTime workDate,
    required String field,
    String? notes,
    required String createdBy,
  }) =>
      Task(
        id: '',
        title: title,
        description: description,
        workTypeId: workTypeId,
        workDate: workDate,
        field: field,
        notes: notes,
        status: TaskStatus.active,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'workTypeId': workTypeId,
        'workDate': workDate.toIso8601String(),
        'field': field,
        'notes': notes,
        'status': status.index,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String? ?? '',
        workTypeId: m['workTypeId'] as String,
        workDate: DateTime.parse(m['workDate'] as String),
        field: m['field'] as String? ?? '',
        notes: m['notes'] as String?,
        status: TaskStatus.values[m['status'] as int],
        createdBy: m['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );

  Task copyWith({
    String? title,
    String? description,
    String? workTypeId,
    DateTime? workDate,
    String? field,
    String? notes,
    TaskStatus? status,
    DateTime? updatedAt,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        workTypeId: workTypeId ?? this.workTypeId,
        workDate: workDate ?? this.workDate,
        field: field ?? this.field,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}