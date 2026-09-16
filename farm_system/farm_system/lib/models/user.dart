import '../core/constants/enums.dart';

class AppUser {
  final String id;
  final String name;
  final UserRole role;

  const AppUser({required this.id, required this.name, required this.role});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role.name,
      };

  factory AppUser.fromMap(Map map) => AppUser(
        id: map['id'] as String,
        name: map['name'] as String,
        role: UserRole.values.byName(map['role'] as String),
      );
}
