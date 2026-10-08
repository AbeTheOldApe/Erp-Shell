import 'package:flutter/foundation.dart';

/// Outcome of an API call. An envelope with `IsSuccessful: false` (a
/// business rule rejection, HTTP 200) and 4xx/5xx responses are both an
/// [ApiFailure]; neither is thrown.
@immutable
sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is ApiSuccess<T>;

  /// The data of a success, otherwise `null`.
  T? get dataOrNull => switch (this) {
    ApiSuccess<T>(:final data) => data,
    ApiFailure<T>() => null,
  };

  /// The failure, if any.
  ApiFailure<T>? get failureOrNull => switch (this) {
    ApiSuccess<T>() => null,
    final ApiFailure<T> failure => failure,
  };
}

class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data, {this.message = '', this.messageCode = 200});

  final T data;
  final String message;
  final int messageCode;
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure({
    required this.httpStatus,
    required this.messageCode,
    this.message = '',
  });

  /// HTTP status; `0` when the server could not be reached.
  final int httpStatus;

  /// `MessageCode` of the envelope (`0` when the response had none).
  final int messageCode;

  /// The server's message (Turkish); shown when [messageCode] has no ARB text.
  final String message;

  bool get isUnauthorized => httpStatus == 401;
  bool get isForbidden => httpStatus == 403;
  bool get isRateLimited => httpStatus == 429;
  bool get isServerError => httpStatus >= 500;
  bool get isNetworkError => httpStatus == 0;

  /// Business rule rejection: HTTP 200 with `IsSuccessful: false`.
  bool get isBusinessRule => httpStatus == 200;

  @override
  String toString() => 'ApiFailure($httpStatus, $messageCode, $message)';
}
