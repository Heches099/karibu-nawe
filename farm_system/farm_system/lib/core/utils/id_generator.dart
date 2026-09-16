import 'package:uuid/uuid.dart';

/// Single source of truth for generating record identifiers.
/// Centralised so the ID strategy can change later (e.g. to
/// server-issued IDs) without touching every model/repository.
class IdGenerator {
  IdGenerator._();
  static const _uuid = Uuid();
  static String next() => _uuid.v4();
}
