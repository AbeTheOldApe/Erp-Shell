import 'package:flutter/foundation.dart';

import 'permissions.dart';

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.roles = const [],
    this.grants,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    username: json['username'] as String? ?? '',
    displayName: json['displayName'] as String,
    roles: [for (final role in json['roles'] as List<dynamic>? ?? []) '$role'],
  );

  final int id;
  final String username;
  final String displayName;
  final List<String> roles;

  /// Page and button grants from the real API's `/me`; `null` in mock mode,
  /// where the menu carries the permissions.
  final ApiGrants? grants;

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'roles': roles,
  };
}

/// Tokens and user returned by `/auth/login` and `/auth/refresh`.
@immutable
class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken = '',
    required this.expiresAt,
    required this.user,
  });

  /// Parses a login response (`expiresInSeconds` is relative to [now]).
  factory AuthSession.fromLoginResponse(
    Map<String, dynamic> json, {
    required String username,
    DateTime? now,
  }) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: (now ?? DateTime.now()).add(
        Duration(seconds: json['expiresInSeconds'] as int),
      ),
      user: AppUser.fromJson({'username': username, ...user}),
    );
  }

  /// Parses the stored form produced by [toJson].
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String accessToken;

  /// Mock mode only; the real API keeps the refresh token in an `httpOnly`
  /// cookie the app cannot read.
  final String refreshToken;
  final DateTime expiresAt;
  final AppUser user;

  AuthSession copyWith({String? accessToken, DateTime? expiresAt}) =>
      AuthSession(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
        user: user,
      );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'user': user.toJson(),
  };
}

/// A sign-in shortcut shown on the login screen (demo environments only).
@immutable
class DemoAccount {
  const DemoAccount({
    required this.username,
    required this.password,
    required this.description,
  });

  final String username;
  final String password;
  final String description;
}
