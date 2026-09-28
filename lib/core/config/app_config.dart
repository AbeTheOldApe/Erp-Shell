import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Environment settings. Values come from `--dart-define`.
///
/// Runtime `config.json` support arrives with the real API (phase 4).
class AppConfig {
  const AppConfig({required this.useMock, required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() => const AppConfig(
    useMock: bool.fromEnvironment('USE_MOCK'),
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: '/api'),
  );

  /// Selects mock repositories instead of HTTP ones.
  final bool useMock;

  /// Base URL of the backend API.
  final String apiBaseUrl;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
