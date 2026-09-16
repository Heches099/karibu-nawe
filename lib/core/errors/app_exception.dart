/// Application errors carrying a friendly message for the user.
class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => message;
}

/// Raised when a business rule is violated.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

class AuthorizationException extends AppException {
  const AuthorizationException(super.message, {super.cause});
}

/// Raised when the requested record does not exist.
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});
}

/// Raised when the persistence backend reports a problem.
class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}