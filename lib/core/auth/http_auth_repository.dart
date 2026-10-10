import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/api_result.dart';
import '../utils/refresh_lock.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'permissions.dart';

/// [AuthRepository] for the real API (`docs/api-contract.md` §4). The access
/// token lives only in memory; the refresh token is an `httpOnly` cookie that
/// the browser sends to `/auth/*` by itself.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ApiClient _client;
  final DateTime Function() _now;

  @override
  bool get persistsSession => false;

  @override
  List<DemoAccount> get demoAccounts => const [];

  @override
  Future<AuthSession> login(String username, String password) async {
    final result = await _client.send<_Token>(
      'POST',
      '/auth/login',
      body: {'KullaniciAdi': username.trim(), 'Sifre': password},
      parse: _Token.parse,
    );
    final token = _unwrap(result);
    return _withUser(token);
  }

  @override
  Future<AuthSession> refresh(AuthSession session) async {
    final token = await _refreshToken();
    return session.copyWith(
      accessToken: token.accessToken,
      expiresAt: _now().add(token.expiresIn),
    );
  }

  @override
  Future<AuthSession?> restoreSession() async {
    try {
      return await _withUser(await _refreshToken());
    } on ApiException {
      return null;
    }
  }

  @override
  Future<void> logout(AuthSession session) async {
    await _client.send<void>('POST', '/auth/logout', parse: (_) {});
  }

  /// `POST /auth/refresh`, one browser tab at a time.
  Future<_Token> _refreshToken() => withRefreshLock(() async {
    final result = await _client.send<_Token>(
      'POST',
      '/auth/refresh',
      parse: _Token.parse,
    );
    return _unwrap(result);
  });

  Future<AuthSession> _withUser(_Token token) async {
    // The token is not in the session state yet, so it is passed explicitly.
    final result = await _client.send<AppUser>(
      'GET',
      '/me',
      headers: {'Authorization': 'Bearer ${token.accessToken}'},
      parse: _parseUser,
    );
    return AuthSession(
      accessToken: token.accessToken,
      expiresAt: _now().add(token.expiresIn),
      user: _unwrap(result),
    );
  }

  static AppUser _parseUser(Object? data) {
    final map = data! as Map<String, dynamic>;
    final user = map['Kullanici'] as Map<String, dynamic>;
    final userName = user['UserName'] as String? ?? '';
    final fullName = (user['FullName'] as String? ?? '').trim();
    final grants = map['Yetkiler'];
    final tenant = map['Tenant'];
    return AppUser(
      integration: IntegrationType.parse(
        tenant is Map<String, dynamic> ? tenant['EntegrasyonTuru'] : null,
      ),
      id: user['AppUserId'] as int,
      username: userName,
      displayName: fullName.isEmpty ? userName : fullName,
      grants: grants is Map<String, dynamic>
          ? ApiGrants.fromJson(grants)
          : ApiGrants.none,
    );
  }

  /// The data of a success; a failure becomes an [ApiException]
  /// ([UnauthorizedException] for 401) carrying the server's message.
  static T _unwrap<T>(ApiResult<T> result) {
    switch (result) {
      case ApiSuccess<T>(:final data):
        return data;
      case ApiFailure<T>(:final httpStatus, :final messageCode, :final message):
        if (httpStatus == 401) {
          throw UnauthorizedException(code: '$messageCode', message: message);
        }
        throw ApiException(
          statusCode: httpStatus,
          code: '$messageCode',
          message: message,
        );
    }
  }
}

class _Token {
  const _Token(this.accessToken, this.expiresIn);

  static _Token parse(Object? data) {
    final map = data! as Map<String, dynamic>;
    return _Token(
      map['AccessToken'] as String,
      Duration(seconds: map['ExpiresIn'] as int? ?? 900),
    );
  }

  final String accessToken;
  final Duration expiresIn;
}
