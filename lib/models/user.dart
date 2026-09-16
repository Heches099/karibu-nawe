import 'enums.dart';

class User {
  final String id;
  final String username;
  final String password;
  final String displayName;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;

  const User({
    required this.id,
    required this.username,
    required this.password,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  factory User.create({
    required String username,
    required String password,
    required String displayName,
    required UserRole role,
  }) =>
      User(
        id: '',
        username: username,
        password: password,
        displayName: displayName,
        role: role,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'password': password,
        'displayName': displayName,
        'role': role.index,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive,
      };

  factory User.fromMap(Map<String, dynamic> m) => User(
        id: m['id'] as String,
        username: m['username'] as String,
        password: m['password'] as String,
        displayName: m['displayName'] as String,
        role: UserRole.values[m['role'] as int],
        createdAt: DateTime.parse(m['createdAt'] as String),
        isActive: m['isActive'] as bool? ?? true,
      );

  User copyWith({String? id, String? username, String? password, String? displayName, UserRole? role, bool? isActive}) =>
      User(
        id: id ?? this.id,
        username: username ?? this.username,
        password: password ?? this.password,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        createdAt: createdAt,
        isActive: isActive ?? this.isActive,
      );
}