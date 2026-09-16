import '../core/constants/enums.dart';

class Task {
  final String id;
  final String title;
  final String? description;
  final String workTypeId;
  final DateTime workDate;
  final String field; // farm/field name
  final String? notes;
  final TaskStatus status;
  final String createdBy;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.workTypeId,
    required this.workDate,
    required this.field,
    this.notes,
    this.status = TaskStatus.active,
    required this.createdBy,
    required this.createdAt,
  });

  Task copyWith({
    String? title,
    String? description,
    DateTime? workDate,
    String? field,
    String? notes,
    TaskStatus? status,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        workTypeId: workTypeId,
        workDate: workDate ?? this.workDate,
        field: field ?? this.field,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        createdBy: createdBy,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'workTypeId': workTypeId,
        'workDate': workDate.toIso8601String(),
        'field': field,
        'notes': notes,
        'status': status.name,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromMap(Map map) => Task(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        workTypeId: map['workTypeId'] as String,
        workDate: DateTime.parse(map['workDate'] as String),
        field: map['field'] as String,
        notes: map['notes'] as String?,
        status: TaskStatus.values.byName(map['status'] as String),
        createdBy: map['createdBy'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
