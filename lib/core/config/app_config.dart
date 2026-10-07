import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Environment settings.
///
/// Precedence: `--dart-define` (`USE_MOCK`, `API_BASE_URL`) > runtime
/// `config.json` > defaults.
class AppConfig {
  const AppConfig({required this.useMock, required this.apiBaseUrl});

  /// Compile-time values only; falls back to defaults when not defined.
  factory AppConfig.fromEnvironment() => AppConfig.resolve();

  /// Merges `--dart-define` values over [runtime] (parsed `config.json`).
  factory AppConfig.resolve([Map<String, dynamic>? runtime]) {
    final runtimeMock = runtime?['useMock'];
    final runtimeBase = runtime?['apiBaseUrl'];
    return AppConfig(
      useMock: const bool.hasEnvironment('USE_MOCK')
          ? const bool.fromEnvironment('USE_MOCK')
          : (runtimeMock is bool ? runtimeMock : false),
      apiBaseUrl: _definedApiBaseUrl.isNotEmpty
          ? _definedApiBaseUrl
          : (runtimeBase is String && runtimeBase.isNotEmpty
                ? runtimeBase
                : defaultApiBaseUrl),
    );
  }

  static const _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const defaultApiBaseUrl = '/api/v1';

  /// Reads `config.json` served next to `index.html`. A missing or invalid
  /// file is not an error: compile-time values and defaults apply.
  static Future<AppConfig> load({Dio? dio}) async {
    try {
      final response = await (dio ?? Dio()).get<Object?>(
        'config.json',
        options: Options(
          headers: {'Cache-Control': 'no-cache'},
          responseType: ResponseType.json,
        ),
      );
      final data = response.data;
      return AppConfig.resolve(data is Map<String, dynamic> ? data : null);
    } on Object {
      return AppConfig.resolve();
    }
  }

  /// Selects mock repositories instead of HTTP ones.
  final bool useMock;

  /// Base URL of the backend API.
  final String apiBaseUrl;
}

/// Overridden in `main()` with the value loaded from `config.json`.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
