/// A class that holds response codes for the application.
abstract class ResponseCode {
  /// Bad request response code.
  static const int badRequestCode = 400;

  /// Unauthorized request response code.
  static const int unauthorizedRequestCode = 401;

  /// Forbidden request response code.
  static const int forbiddenRequestCode = 403;

  /// Resource not found response code.
  static const int resourceNotFoundCode = 404;

  /// Request timeout response code.
  static const int requestTimeoutCode = 408;

  /// Conflict occurred response code.
  static const int conflictOccurredCode = 409;

  /// Too many requests response code.
  static const int tooManyRequestsCode = 429;

  /// Internal server error response code.
  static const int internalServerErrorCode = 500;

  /// Service unavailable response code.
  static const int serviceUnavailableCode = 503;
}
