import 'package:uuid/uuid.dart';

class IdGen {
  IdGen._();
  static const _u = Uuid();

  static String newId() => _u.v4();
}