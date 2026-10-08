import '../../data/mock/mock_backend.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

/// [AuthRepository] backed by [MockBackend].
class MockAuthRepository implements AuthRepository, SessionExpirySimulator {
  MockAuthRepository(this._backend);

  final MockBackend _backend;

  @override
  bool get persistsSession => true;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login(String username, String password) async {
    await _backend.latency();
    final normalized = username.trim();
    final response = _backend.login(normalized);
    return AuthSession.fromLoginResponse(response, username: normalized);
  }

  @override
  Future<AuthSession> refresh(AuthSession session) async {
    await _backend.latency();
    final response = _backend.refresh(session.refreshToken);
    return AuthSession.fromLoginResponse(
      response,
      username: session.user.username,
    );
  }

  @override
  Future<void> logout(AuthSession session) async {
    _backend.logout(session.accessToken, session.refreshToken);
  }

  @override
  void expireSession(AuthSession session) =>
      _backend.revoke(session.accessToken, session.refreshToken);

  @override
  List<DemoAccount> get demoAccounts => const [
    DemoAccount(
      username: 'yonetici',
      password: '1234',
      description: 'Yonetici',
    ),
    DemoAccount(username: 'depo', password: '1234', description: 'Depo'),
    DemoAccount(username: 'satis', password: '1234', description: 'Satis'),
  ];
}
