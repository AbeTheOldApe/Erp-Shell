import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:erp_shell/app.dart';
import 'package:erp_shell/core/auth/session_controller.dart';
import 'package:erp_shell/core/config/app_config.dart';
import 'package:erp_shell/core/l10n/generated/app_localizations_tr.dart';
import 'package:erp_shell/core/network/api_client.dart';
import 'package:erp_shell/core/network/api_exception.dart';
import 'package:erp_shell/core/network/api_messages.dart';
import 'package:erp_shell/core/network/api_result.dart';
import 'package:erp_shell/core/router/app_router.dart';
import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/core/storage/storage_keys.dart';
import 'package:erp_shell/shell/login/login_page.dart';
import 'package:erp_shell/shell/shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reply {
  const _Reply(this.status, this.body);

  factory _Reply.ok(Object? data) => _Reply(200, {
    'IsSuccessful': true,
    'Message': 'Islem basarili.',
    'MessageCode': 200,
    'Data': data,
  });

  factory _Reply.fail(int status, int code, String message) => _Reply(status, {
    'IsSuccessful': false,
    'Message': message,
    'MessageCode': code,
    'Data': null,
  });

  final int status;
  final Object? body;
}

class _Recorded {
  _Recorded(RequestOptions options)
    : method = options.method,
      path = options.path,
      headers = Map.of(options.headers);

  final String method;
  final String path;
  final Map<String, dynamic> headers;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final FutureOr<_Reply> Function(RequestOptions options) handler;
  final requests = <_Recorded>[];

  int count(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(_Recorded(options));
    final reply = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SpyStore extends MemoryKeyValueStore {
  final writes = <String, String>{};

  @override
  void write(String key, String value) {
    writes[key] = value;
    super.write(key, value);
  }
}

const _me = {
  'Kullanici': {
    'AppUserId': 13,
    'TenantId': 2,
    'UserName': 'esin',
    'FullName': '',
    'Email': 'e@x.com',
  },
  'Ortam': 'Test',
  'Menu': [],
  'Yetkiler': {
    'Pages': ['CariMain'],
    'Buttons': {
      'CariMain': ['KAYDET'],
    },
  },
};

_Reply _token(String token) =>
    _Reply.ok({'AccessToken': token, 'ExpiresIn': 900, 'TokenType': 'Bearer'});

/// A server that issues `t1` on login and `t2` on refresh, and accepts
/// `/things` only with `t2`.
FutureOr<_Reply> _server(RequestOptions o, {bool refreshWorks = true}) async {
  switch (o.path) {
    case '/auth/login':
      return _token('t1');
    case '/auth/refresh':
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return refreshWorks
          ? _token('t2')
          : _Reply.fail(401, 2003, 'Oturum gecersiz.');
    case '/me':
      return _Reply.ok(_me);
    case '/things':
      return o.headers['Authorization'] == 'Bearer t2'
          ? _Reply.ok({'Value': 1})
          : _Reply.fail(401, 2003, 'Oturum yok.');
    default:
      return _Reply.fail(404, 2004, 'Yok.');
  }
}

ProviderContainer _container(
  _FakeAdapter adapter, {
  MemoryKeyValueStore? local,
  MemoryKeyValueStore? session,
}) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(useMock: false, apiBaseUrl: 'http://localhost/api/v1'),
      ),
      httpClientAdapterProvider.overrideWithValue(adapter),
      localStoreProvider.overrideWithValue(local ?? MemoryKeyValueStore()),
      sessionStoreProvider.overrideWithValue(session ?? MemoryKeyValueStore()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settled(ProviderContainer container) async {
  for (var i = 0; i < 200; i++) {
    if (!container.read(sessionProvider).isRestoring) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('startup refresh did not finish');
}

Future<ApiResult<Object?>> _getThings(ProviderContainer c) => c
    .read(apiClientProvider)
    .send<Object?>('GET', '/things', parse: (data) => data);

void main() {
  group('envelope', () {
    test(
      '200 + IsSuccessful=false is a failure value, not an exception',
      () async {
        final adapter = _FakeAdapter(
          (_) => _Reply.fail(200, 1004, 'Kayit bulunamadi.'),
        );
        final result = await _container(
          adapter,
        ).read(apiClientProvider).send<Object?>('GET', '/x', parse: (d) => d);
        final failure = result.failureOrNull!;
        expect(failure.httpStatus, 200);
        expect(failure.isBusinessRule, isTrue);
        expect(failure.messageCode, 1004);
        expect(failure.message, 'Kayit bulunamadi.');
      },
    );

    test('success parses Data', () async {
      final adapter = _FakeAdapter((_) => _Reply.ok({'A': 1}));
      final result = await _container(adapter)
          .read(apiClientProvider)
          .send<int>(
            'GET',
            '/x',
            parse: (d) => (d! as Map<String, dynamic>)['A'] as int,
          );
      expect(result.dataOrNull, 1);
    });

    test('4xx and 5xx map to ApiFailure', () async {
      final statuses = {
        400: 2001,
        403: 2003,
        404: 2004,
        422: 2002,
        429: 2005,
        500: 2999,
      };
      for (final entry in statuses.entries) {
        final adapter = _FakeAdapter(
          (_) => _Reply.fail(entry.key, entry.value, 'm'),
        );
        final result = await _container(
          adapter,
        ).read(apiClientProvider).send<Object?>('GET', '/x', parse: (d) => d);
        expect(result.failureOrNull!.httpStatus, entry.key);
        expect(result.failureOrNull!.messageCode, entry.value);
      }
    });

    test('500 shows the generic text, unknown codes the server message', () {
      final l10n = AppLocalizationsTr();
      const server = ApiFailure<Object?>(
        httpStatus: 500,
        messageCode: 2999,
        message: 'stack trace',
      );
      expect(apiFailureText(l10n, server), l10n.apiMessage2999);
      const unknown = ApiFailure<Object?>(
        httpStatus: 200,
        messageCode: 1234,
        message: 'Ozel mesaj',
      );
      expect(apiFailureText(l10n, unknown), 'Ozel mesaj');
      const known = ApiFailure<Object?>(
        httpStatus: 200,
        messageCode: 1004,
        message: 'sunucu',
      );
      expect(apiFailureText(l10n, known), l10n.apiMessage1004);
    });

    test('login errors: server message for 401, own text for 429', () {
      final l10n = AppLocalizationsTr();
      expect(
        loginErrorText(l10n, const UnauthorizedException(message: 'Kilitli.')),
        'Kilitli.',
      );
      expect(
        loginErrorText(
          l10n,
          const ApiException(statusCode: 429, code: '2005', message: 'x'),
        ),
        l10n.loginTooManyAttempts,
      );
    });
  });

  group('headers', () {
    test('/auth/* has X-Requested-With and no Authorization', () async {
      final adapter = _FakeAdapter(_server);
      final container = _container(adapter);
      await _settled(container);
      await container.read(sessionProvider.notifier).login('esin', 'x');
      final login = adapter.requests.firstWhere((r) => r.path == '/auth/login');
      expect(login.headers['X-Requested-With'], 'OptiCodeApp');
      expect(login.headers.containsKey('Authorization'), isFalse);
      expect(login.method, 'POST');
      final refresh = adapter.requests.firstWhere(
        (r) => r.path == '/auth/refresh',
      );
      expect(refresh.headers['X-Requested-With'], 'OptiCodeApp');
      expect(refresh.headers.containsKey('Authorization'), isFalse);
    });

    test('other requests carry the bearer token', () async {
      final adapter = _FakeAdapter(_server);
      final container = _container(adapter);
      await _settled(container);
      await container.read(sessionProvider.notifier).login('esin', 'x');
      await _getThings(container);
      final call = adapter.requests.firstWhere((r) => r.path == '/things');
      expect(call.headers['Authorization'], 'Bearer t1');
    });
  });

  group('session', () {
    test('login loads the user and grants from /me', () async {
      final container = _container(_FakeAdapter(_server));
      await _settled(container);
      await container.read(sessionProvider.notifier).login('esin', 'x');
      final user = container.read(sessionProvider).user!;
      expect(user.id, 13);
      expect(user.displayName, 'esin'); // FullName is empty
      expect(user.grants!.hasPage('CariMain'), isTrue);
      expect(user.grants!.hasButton('CariMain', 'KAYDET'), isTrue);
      expect(user.grants!.hasButton('CariMain', 'SIL'), isFalse);
    });

    test('the access token is never written to a store', () async {
      final local = _SpyStore();
      final session = _SpyStore();
      final container = _container(
        _FakeAdapter(_server),
        local: local,
        session: session,
      );
      await _settled(container);
      await container.read(sessionProvider.notifier).login('esin', 'x');
      await _getThings(container); // forces a refresh to t2
      for (final store in [local, session]) {
        expect(store.writes.containsKey(StorageKeys.authTokens), isFalse);
        expect(
          store.writes.values.any((v) => v.contains('t1') || v.contains('t2')),
          isFalse,
        );
      }
    });

    test('two concurrent 401s trigger a single refresh', () async {
      final adapter = _FakeAdapter(_server);
      final container = _container(adapter);
      await _settled(container);
      await container.read(sessionProvider.notifier).login('esin', 'x');
      final startupRefreshes = adapter.count('/auth/refresh');
      final results = await Future.wait([
        _getThings(container),
        _getThings(container),
      ]);
      expect(results.every((r) => r.isSuccess), isTrue);
      expect(adapter.count('/auth/refresh') - startupRefreshes, 1);
      expect(adapter.count('/things'), 4); // each request tried twice
      expect(container.read(sessionProvider).session!.accessToken, 't2');
    });

    test('a request is repeated once; a second 401 is not retried', () async {
      final adapter = _FakeAdapter((o) {
        if (o.path == '/things') return _Reply.fail(401, 2003, 'Hep 401');
        return _server(o);
      });
      final container = _container(adapter);
      await _settled(container);
      await container.read(sessionProvider.notifier).login('esin', 'x');
      final before = adapter.count('/auth/refresh');
      final result = await _getThings(container);
      expect(result.failureOrNull!.isUnauthorized, isTrue);
      expect(adapter.count('/things'), 2);
      expect(adapter.count('/auth/refresh') - before, 1);
      expect(container.read(sessionProvider).status, SessionStatus.active);
    });

    test('a failed refresh expires the session and keeps the user', () async {
      var refreshWorks = true;
      final adapter = _FakeAdapter(
        (o) => _server(o, refreshWorks: refreshWorks),
      );
      final container = _container(adapter);
      await _settled(container);
      await container.read(sessionProvider.notifier).login('esin', 'x');
      refreshWorks = false;
      await expectLater(
        _getThings(container),
        throwsA(isA<SessionExpiredException>()),
      );
      final state = container.read(sessionProvider);
      expect(state.status, SessionStatus.expired);
      expect(state.user!.username, 'esin');
    });

    test('logout posts /auth/logout and clears the memory', () async {
      final adapter = _FakeAdapter((o) {
        if (o.path == '/auth/logout') return _Reply.ok(null);
        return _server(o);
      });
      final container = _container(adapter);
      await _settled(container);
      final notifier = container.read(sessionProvider.notifier);
      await notifier.login('esin', 'x');
      await notifier.logout();
      expect(adapter.count('/auth/logout'), 1);
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
    });
  });

  group('startup', () {
    test('failed silent refresh leads to signed out', () async {
      final adapter = _FakeAdapter((o) => _server(o, refreshWorks: false));
      final container = _container(adapter);
      expect(container.read(sessionProvider).isRestoring, isTrue);
      await _settled(container);
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
      expect(adapter.count('/me'), 0);
    });

    test('successful silent refresh loads /me', () async {
      final adapter = _FakeAdapter(_server);
      final container = _container(adapter);
      await _settled(container);
      final state = container.read(sessionProvider);
      expect(state.status, SessionStatus.active);
      expect(state.session!.accessToken, 't2');
      expect(state.user!.id, 13);
      final me = adapter.requests.firstWhere((r) => r.path == '/me');
      expect(me.headers['Authorization'], 'Bearer t2');
    });

    test('a token left in sessionStorage is not read', () async {
      final session = MemoryKeyValueStore({
        StorageKeys.authTokens: jsonEncode({
          'accessToken': 'old',
          'refreshToken': 'old',
          'expiresAt': DateTime(2100).toIso8601String(),
          'user': {'id': 1, 'username': 'x', 'displayName': 'X'},
        }),
      });
      final container = _container(
        _FakeAdapter((o) => _server(o, refreshWorks: false)),
        session: session,
      );
      expect(container.read(sessionProvider).isRestoring, isTrue);
      await _settled(container);
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
      expect(session.read(StorageKeys.authTokens), isNull);
    });
  });

  group('router guard', () {
    test('waits on the loading page while restoring', () {
      expect(
        authRedirect(
          signedIn: false,
          restoring: true,
          uri: Uri.parse('/m/cari?id=3'),
        ),
        '/loading?from=%2Fm%2Fcari%3Fid%3D3',
      );
      expect(
        authRedirect(signedIn: false, restoring: true, uri: Uri.parse('/')),
        '/loading',
      );
      expect(
        authRedirect(
          signedIn: false,
          restoring: true,
          uri: Uri.parse('/loading'),
        ),
        isNull,
      );
    });

    test('after restoring the loading page returns to the wanted page', () {
      final uri = Uri.parse('/loading?from=%2Fm%2Fcari%3Fid%3D3');
      expect(authRedirect(signedIn: true, uri: uri), '/m/cari?id=3');
      expect(
        authRedirect(signedIn: false, uri: uri),
        '/login?from=%2Fm%2Fcari%3Fid%3D3',
      );
      expect(
        authRedirect(signedIn: false, uri: Uri.parse('/loading')),
        '/login',
      );
      expect(authRedirect(signedIn: true, uri: Uri.parse('/loading')), '/');
    });

    test('signed out goes to login and back via from', () {
      expect(
        authRedirect(signedIn: false, uri: Uri.parse('/m/cari')),
        '/login?from=%2Fm%2Fcari',
      );
      expect(
        authRedirect(signedIn: true, uri: Uri.parse('/login?from=%2Fm%2Fcari')),
        '/m/cari',
      );
    });
  });

  group('app startup (real mode)', () {
    Future<void> pumpReal(WidgetTester tester, _FakeAdapter adapter) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                useMock: false,
                apiBaseUrl: 'http://localhost/api/v1',
              ),
            ),
            httpClientAdapterProvider.overrideWithValue(adapter),
            localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
            sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          ],
          child: const App(),
        ),
      );
    }

    testWidgets('refresh fails: the login page, without a demo picker', (
      tester,
    ) async {
      final adapter = _FakeAdapter(
        (o) => o.path == '/auth/refresh'
            ? _Reply.fail(401, 2003, 'Oturum yok.')
            : _server(o),
      );
      await pumpReal(tester, adapter);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(ShellPage), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('refresh succeeds: /me is loaded and the shell is shown', (
      tester,
    ) async {
      final adapter = _FakeAdapter((o) {
        if (o.path == '/auth/refresh') return _token('t2');
        return _server(o);
      });
      await pumpReal(tester, adapter);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(adapter.count('/auth/refresh'), 1);
      expect(adapter.count('/me'), 1);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(ShellPage), findsOneWidget);
    });
  });
}
