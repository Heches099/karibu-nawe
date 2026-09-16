class Worker {
  final String id;
  final String name;
  final String? phone;
  final DateTime createdAt;

  const Worker({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  Worker copyWith({String? name, String? phone}) => Worker(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Worker.fromMap(Map map) => Worker(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
