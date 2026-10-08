import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Adds the auth headers and handles 401 (`docs/api-contract.md` §3, §4.3).
///
/// - `/auth/*` requests carry `X-Requested-With: OptiCodeApp` and never a
///   bearer token.
/// - Other requests carry `Authorization: Bearer` (unless already set) and
///   the same `X-Requested-With`.
/// - A 401 on a non-`/auth/*` request runs [refresh] once and repeats the
///   request once. If the refresh fails the request fails with a
///   [SessionExpiredException].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.accessToken,
    required this.refresh,
    this.onForbidden,
  });

  static const requestedWithHeader = 'X-Requested-With';
  static const requestedWithValue = 'OptiCodeApp';
  static const _retriedKey = 'authRetried';

  final Dio dio;
  final String? Function() accessToken;

  /// Single-flight refresh; `false` when the session could not be renewed.
  final Future<bool> Function() refresh;

  /// Called when a non-`/auth/*` request is answered with 403 (the user's
  /// permissions may have changed).
  final void Function()? onForbidden;

  static bool isAuthPath(String path) => path.contains('/auth/');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[requestedWithHeader] = requestedWithValue;
    if (isAuthPath(options.path)) {
      options.headers.remove('Authorization');
    } else if (!options.headers.containsKey('Authorization')) {
      final token = accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode == 403 && !isAuthPath(request.path)) {
      onForbidden?.call();
    }
    final retryable =
        err.response?.statusCode == 401 &&
        !isAuthPath(request.path) &&
        request.extra[_retriedKey] != true;
    if (!retryable) return handler.next(err);

    if (!await refresh()) {
      return handler.reject(
        DioException(
          requestOptions: request,
          response: err.response,
          error: const SessionExpiredException(),
        ),
      );
    }
    try {
      // The retry takes the renewed token in onRequest.
      request.headers.remove('Authorization');
      request.extra[_retriedKey] = true;
      handler.resolve(await dio.fetch<Object?>(request));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }
}
