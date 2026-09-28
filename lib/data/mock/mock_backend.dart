import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';

/// In-memory stand-in for the backend used by the mock repositories.
///
/// Tokens are self-describing (`mock-at.<username>.<issuedAtMs>.<nonce>`) so a
/// session survives a page reload; only explicitly revoked tokens are
/// remembered.
class MockBackend {
  MockBackend({
    Duration minLatency = const Duration(milliseconds: 300),
    Duration maxLatency = const Duration(milliseconds: 600),
    Random? random,
    DateTime Function()? clock,
  }) : _minLatency = minLatency,
       _maxLatency = maxLatency,
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now;

  static const accessTokenLifetime = Duration(seconds: 900);

  static const users = <String, MockUser>{
    'yonetici': MockUser(1, 'Yönetici Kullanıcı', ['Yonetici']),
    'depo': MockUser(2, 'Depo Sorumlusu', ['Depo']),
    'satis': MockUser(3, 'Satış Temsilcisi', ['Satis']),
  };

  final Duration _minLatency;
  final Duration _maxLatency;
  final Random _random;
  final DateTime Function() _clock;
  final Set<String> _revoked = {};

  /// Simulated network delay.
  Future<void> latency() {
    final spread = _maxLatency.inMilliseconds - _minLatency.inMilliseconds;
    final ms = _minLatency.inMilliseconds +
        (spread > 0 ? _random.nextInt(spread + 1) : 0);
    return Future<void>.delayed(Duration(milliseconds: ms));
  }

  /// `POST /auth/login` response body. Passwords are not checked (demo).
  Map<String, dynamic> login(String username) {
    final user = users[username];
    if (user == null) {
      throw const UnauthorizedException(
        code: 'invalid_credentials',
        message: 'Invalid username or password.',
      );
    }
    return _tokenResponse(username, user);
  }

  /// `POST /auth/refresh` response body.
  Map<String, dynamic> refresh(String refreshToken) {
    final username = _parse(refreshToken, prefix: 'mock-rt');
    if (username == null || _revoked.contains(refreshToken)) {
      throw const UnauthorizedException(code: 'invalid_refresh_token');
    }
    _revoked.add(refreshToken);
    return _tokenResponse(username, users[username]!);
  }

  void logout(String accessToken, String refreshToken) {
    _revoked
      ..add(accessToken)
      ..add(refreshToken);
  }

  /// Returns the username for a valid access token, otherwise throws 401.
  String authenticate(String? accessToken) {
    if (accessToken == null || _revoked.contains(accessToken)) {
      throw const UnauthorizedException();
    }
    final parts = accessToken.split('.');
    final username = _parse(accessToken, prefix: 'mock-at');
    final issuedAt = parts.length == 4 ? int.tryParse(parts[2]) : null;
    if (username == null || issuedAt == null) {
      throw const UnauthorizedException();
    }
    final age = _clock().millisecondsSinceEpoch - issuedAt;
    if (age > accessTokenLifetime.inMilliseconds) {
      throw const UnauthorizedException(code: 'token_expired');
    }
    return username;
  }

  /// Revokes both tokens: the next call gets 401 and refresh fails.
  void revoke(String accessToken, String refreshToken) =>
      logout(accessToken, refreshToken);

  Map<String, dynamic> _tokenResponse(String username, MockUser user) {
    final now = _clock().millisecondsSinceEpoch;
    final nonce = _random.nextInt(0x7fffffff).toRadixString(16);
    return {
      'accessToken': 'mock-at.$username.$now.$nonce',
      'refreshToken': 'mock-rt.$username.$now.$nonce',
      'expiresInSeconds': accessTokenLifetime.inSeconds,
      'user': {
        'id': user.id,
        'displayName': user.displayName,
        'roles': user.roles,
      },
    };
  }

  String? _parse(String token, {required String prefix}) {
    final parts = token.split('.');
    if (parts.length != 4 || parts[0] != prefix) return null;
    return users.containsKey(parts[1]) ? parts[1] : null;
  }
}

class MockUser {
  const MockUser(this.id, this.displayName, this.roles);

  final int id;
  final String displayName;
  final List<String> roles;
}

final mockBackendProvider = Provider<MockBackend>((ref) => MockBackend());
