import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_exception.dart';
import '../storage/key_value_store.dart';
import '../storage/storage_keys.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

enum SessionStatus {
  /// No user; the router sends everything to the login page.
  signedOut,

  /// Signed in and tokens are usable.
  active,

  /// Tokens could not be refreshed. The shell (and its tabs) stays in place
  /// behind a blocking "sign in again" dialog.
  expired,
}

@immutable
class SessionState {
  const SessionState._(this.status, this.session);

  const SessionState.signedOut() : this._(SessionStatus.signedOut, null);

  const SessionState.active(AuthSession session)
    : this._(SessionStatus.active, session);

  const SessionState.expired(AuthSession session)
    : this._(SessionStatus.expired, session);

  final SessionStatus status;
  final AuthSession? session;

  AppUser? get user => session?.user;
  bool get isSignedIn => status != SessionStatus.signedOut;
}

class SessionController extends Notifier<SessionState> {
  Future<bool>? _refreshing;

  AuthRepository get _repository => ref.read(authRepositoryProvider);
  KeyValueStore get _store => ref.read(sessionStoreProvider);

  @override
  SessionState build() {
    final stored = _store.read(StorageKeys.authTokens);
    if (stored == null) return const SessionState.signedOut();
    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      return SessionState.active(AuthSession.fromJson(json));
    } catch (_) {
      _store.remove(StorageKeys.authTokens);
      return const SessionState.signedOut();
    }
  }

  /// Signs in. Also used by the "session expired" dialog; tabs stay open
  /// because the user does not change.
  Future<void> login(String username, String password) async {
    final session = await _repository.login(username, password);
    _setActive(session);
  }

  Future<void> logout() async {
    final session = state.session;
    _store.remove(StorageKeys.authTokens);
    state = const SessionState.signedOut();
    if (session != null) {
      try {
        await _repository.logout(session);
      } catch (_) {
        // Logging out locally is enough; the server call is best effort.
      }
    }
  }

  /// Runs an authorized API call. On 401 the tokens are refreshed once and
  /// the call is retried; if the refresh fails the session becomes
  /// [SessionStatus.expired] and [SessionExpiredException] is thrown.
  Future<T> guard<T>(Future<T> Function() request) async {
    if (state.status == SessionStatus.expired) {
      throw const SessionExpiredException();
    }
    try {
      return await request();
    } on UnauthorizedException {
      if (!await _refresh()) throw const SessionExpiredException();
      return request();
    }
  }

  /// Whether the "Oturum süresini doldur" developer command is available.
  bool get canSimulateExpiry => _repository is SessionExpirySimulator;

  /// Invalidates the tokens so that the next API call fails with 401.
  void simulateExpiry() {
    final session = state.session;
    if (session == null) return;
    if (_repository case final SessionExpirySimulator simulator) {
      simulator.expireSession(session);
    }
  }

  Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final session = state.session;
    if (session == null) return false;
    try {
      _setActive(await _repository.refresh(session));
      return true;
    } on ApiException {
      if (state.session != null) state = SessionState.expired(session);
      return false;
    }
  }

  void _setActive(AuthSession session) {
    _store.write(StorageKeys.authTokens, jsonEncode(session.toJson()));
    state = SessionState.active(session);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Id of the signed-in user; changes only on sign-in / sign-out, not when the
/// session expires.
final currentUserIdProvider = Provider<int?>(
  (ref) => ref.watch(sessionProvider.select((s) => s.user?.id)),
);
