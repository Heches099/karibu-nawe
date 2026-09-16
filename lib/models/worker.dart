class Worker {
  final String id;
  final String name;
  final String phone;
  final String? field;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  const Worker({
    required this.id,
    required this.name,
    required this.phone,
    this.field,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  factory Worker.create({required String name, String phone = '', String? field, String? notes}) => Worker(
        id: '',
        name: name,
        phone: phone,
        field: field,
        notes: notes,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'field': field,
        'notes': notes,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Worker.fromMap(Map<String, dynamic> m) => Worker(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String? ?? '',
        field: m['field'] as String?,
        notes: m['notes'] as String?,
        isActive: m['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  Worker copyWith({String? name, String? phone, String? field, String? notes, bool? isActive}) =>
      Worker(id: id, name: name ?? this.name, phone: phone ?? this.phone, field: field ?? this.field, notes: notes ?? this.notes, isActive: isActive ?? this.isActive, createdAt: createdAt);
}