import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_result.dart';
import 'auth_interceptor.dart';

/// Counts 403 answers of the API. The shell listens and warns on the tab that
/// was active ("Yetkiniz değişmiş olabilir").
class ForbiddenEvents extends Notifier<int> {
  @override
  int build() => 0;

  void report() => state++;
}

final forbiddenEventsProvider = NotifierProvider<ForbiddenEvents, int>(
  ForbiddenEvents.new,
);

/// Replaces the HTTP adapter of [dioProvider] (tests).
final httpClientAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// Shared [Dio] instance with the auth interceptor.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
    ),
  );
  final adapter = ref.watch(httpClientAdapterProvider);
  if (adapter != null) dio.httpClientAdapter = adapter;
  // The session is read lazily: the session controller depends on the auth
  // repository, which depends on this client.
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      accessToken: () => ref.read(sessionProvider).session?.accessToken,
      refresh: () => ref.read(sessionProvider.notifier).refreshSession(),
      onForbidden: () => ref.read(forbiddenEventsProvider.notifier).report(),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);

/// Sends requests and parses the response envelope
/// `{ IsSuccessful, Message, MessageCode, Data }` (`docs/api-contract.md` §2).
class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  /// Sends a request and maps the outcome to an [ApiResult]; only an
  /// unrecoverable session ([SessionExpiredException]) is thrown. [parse]
  /// converts the envelope's `Data`.
  Future<ApiResult<T>> send<T>(
    String method,
    String path, {
    required T Function(Object? data) parse,
    Map<String, dynamic>? query,
    Object? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
      return _fromBody(response.statusCode ?? 0, response.data, parse);
    } on DioException catch (e) {
      if (e.error is SessionExpiredException) {
        throw e.error! as SessionExpiredException;
      }
      final response = e.response;
      if (response == null) {
        return ApiFailure<T>(httpStatus: 0, messageCode: 0);
      }
      return _fromBody(response.statusCode ?? 0, response.data, parse);
    }
  }

  ApiResult<T> _fromBody<T>(
    int status,
    Object? body,
    T Function(Object? data) parse,
  ) {
    final envelope = body is Map ? body : null;
    final message = envelope?['Message'];
    final code = envelope?['MessageCode'];
    final ok = status >= 200 && status < 300;
    if (ok && envelope != null && envelope['IsSuccessful'] == true) {
      try {
        return ApiSuccess<T>(
          parse(envelope['Data']),
          message: message is String ? message : '',
          messageCode: code is int ? code : status,
        );
      } on Object {
        // A success envelope whose data does not have the expected shape.
        return ApiFailure<T>(httpStatus: 500, messageCode: 2999);
      }
    }
    return ApiFailure<T>(
      httpStatus: status,
      messageCode: code is int ? code : 0,
      message: message is String ? message : '',
    );
  }
}
