import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_backend.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import 'auth_models.dart';
import 'http_auth_repository.dart';
import 'mock_auth_repository.dart';

/// Authentication API. Mock mode follows `docs/menu-schema.md` §1, real mode
/// `docs/api-contract.md` §4.
abstract class AuthRepository {
  /// `POST /auth/login`. Throws [UnauthorizedException] on bad credentials.
  Future<AuthSession> login(String username, String password);

  /// `POST /auth/refresh`. Throws [UnauthorizedException] when the refresh
  /// token is no longer valid.
  Future<AuthSession> refresh(AuthSession session);

  /// `POST /auth/logout`.
  Future<void> logout(AuthSession session);

  /// Whether the session is kept in `sessionStorage` across reloads (mock
  /// mode). The real API keeps the access token in memory only.
  bool get persistsSession => true;

  /// Silent sign-in at startup: refreshes with the browser's cookie and
  /// loads the user. `null` when there is no valid session. Only used when
  /// [persistsSession] is `false`.
  Future<AuthSession?> restoreSession() async => null;

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
  return HttpAuthRepository(ref.watch(apiClientProvider));
});
