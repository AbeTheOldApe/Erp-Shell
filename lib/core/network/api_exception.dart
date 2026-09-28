/// Error returned by the API: `{ "code": "...", "message": "..." }`.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    this.message = '',
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

/// HTTP 401: no session or the token expired.
class UnauthorizedException extends ApiException {
  const UnauthorizedException({super.code = 'unauthorized', super.message})
    : super(statusCode: 401);
}

/// HTTP 403: the user lacks the permission.
class ForbiddenException extends ApiException {
  const ForbiddenException({super.code = 'forbidden', super.message})
    : super(statusCode: 403);
}

/// Thrown when the session could not be refreshed and the user must sign in
/// again.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
}
