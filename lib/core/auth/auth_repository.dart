import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_backend.dart';
import '../config/app_config.dart';
import 'auth_models.dart';
import 'mock_auth_repository.dart';

/// Authentication API (`docs/menu-schema.md` §1).
abstract class AuthRepository {
  /// `POST /auth/login`. Throws [UnauthorizedException] on bad credentials.
  Future<AuthSession> login(String username, String password);

  /// `POST /auth/refresh`. Throws [UnauthorizedException] when the refresh
  /// token is no longer valid.
  Future<AuthSession> refresh(AuthSession session);

  /// `POST /auth/logout`.
  Future<void> logout(AuthSession session);

  /// Sign-in shortcuts for demo environments; empty for the real API.
  List<DemoAccount> get demoAccounts => const [];
}

/// Implemented by repositories that can simulate an expired session
/// (the "Oturum süresini doldur" developer command).
abstract interface class SessionExpirySimulator {
  /// Invalidates the current tokens so the next API call returns 401 and the
  /// refresh fails.
  void expireSession(AuthSession session);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return MockAuthRepository(ref.watch(mockBackendProvider));
  }
  throw UnimplementedError(
    'HttpAuthRepository arrives in phase 4. '
    'Run with --dart-define=USE_MOCK=true.',
  );
});
