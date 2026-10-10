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

import '../helpers/fake_api.dart';

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
  'Menu': <Object?>[],
  'Yetkiler': {
    'Pages': ['CariMain'],
    'Buttons': {
      'CariMain': ['KAYDET'],
    },
  },
};

FakeReply tokenReply(String token) => FakeReply.ok({
  'AccessToken': token,
  'ExpiresIn': 900,
  'TokenType': 'Bearer',
});

/// A server that issues `t1` on login and `t2` on refresh, and accepts
/// `/things` only with `t2`.
FutureOr<FakeReply> _server(
  RequestOptions o, {
  bool refreshWorks = true,
}) async {
  switch (o.path) {
    case '/auth/login':
      return tokenReply('t1');
    case '/auth/refresh':
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return refreshWorks
          ? tokenReply('t2')
          : FakeReply.fail(401, 2003, 'Oturum gecersiz.');
    case '/me':
      return FakeReply.ok(_me);
    case '/things':
      return o.headers['Authorization'] == 'Bearer t2'
          ? FakeReply.ok({'Value': 1})
          : FakeReply.fail(401, 2003, 'Oturum yok.');
    default:
      return FakeReply.fail(404, 2004, 'Yok.');
  }
}

ProviderContainer _container(
  FakeAdapter adapter, {
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
        final adapter = FakeAdapter(
          (_) => FakeReply.fail(200, 1004, 'Kayit bulunamadi.'),
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
      final adapter = FakeAdapter((_) => FakeReply.ok({'A': 1}));
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
        final adapter = FakeAdapter(
          (_) => FakeReply.fail(entry.key, entry.value, 'm'),
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
      final adapter = FakeAdapter(_server);
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
      final adapter = FakeAdapter(_server);
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
      final container = _container(FakeAdapter(_server));
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
        FakeAdapter(_server),
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
      final adapter = FakeAdapter(_server);
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
      final adapter = FakeAdapter((o) {
        if (o.path == '/things') return FakeReply.fail(401, 2003, 'Hep 401');
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
      final adapter = FakeAdapter(
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
      final adapter = FakeAdapter((o) {
        if (o.path == '/auth/logout') return FakeReply.ok(null);
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
      final adapter = FakeAdapter((o) => _server(o, refreshWorks: false));
      final container = _container(adapter);
      expect(container.read(sessionProvider).isRestoring, isTrue);
      await _settled(container);
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
      expect(adapter.count('/me'), 0);
    });

    test('successful silent refresh loads /me', () async {
      final adapter = FakeAdapter(_server);
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
        FakeAdapter((o) => _server(o, refreshWorks: false)),
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

    test('from is used only for in-app paths other than the auth pages', () {
      String? after(String from) => authRedirect(
        signedIn: true,
        uri: Uri(path: '/login', queryParameters: {'from': from}),
      );
      expect(after('/m/cari?id=3'), '/m/cari?id=3');
      expect(after('/login'), '/');
      expect(after('/login?from=%2Fm%2Fx'), '/');
      expect(after('/loading'), '/');
      expect(after('https://evil.example/x'), '/');
      expect(after('//evil.example/x'), '/');
      expect(authRedirect(signedIn: true, uri: Uri.parse('/login')), '/');
    });

    test('a reload on /login does not come back to /login', () {
      expect(
        authRedirect(
          signedIn: false,
          restoring: true,
          uri: Uri.parse('/login'),
        ),
        '/loading',
      );
      expect(
        authRedirect(signedIn: true, uri: Uri.parse('/loading?from=%2Flogin')),
        '/',
      );
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
    Future<void> settleApp(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpReal(WidgetTester tester, FakeAdapter adapter) async {
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
      final adapter = FakeAdapter(
        (o) => o.path == '/auth/refresh'
            ? FakeReply.fail(401, 2003, 'Oturum yok.')
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

    Future<ProviderContainer> pumpSignedIn(
      WidgetTester tester, {
      String? route,
    }) async {
      if (route != null) {
        tester.platformDispatcher.defaultRouteNameTestValue = route;
        addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      }
      final adapter = FakeAdapter((o) {
        if (o.path == '/auth/refresh') return tokenReply('t2');
        if (o.path == '/auth/logout') return FakeReply.ok(null);
        return _server(o);
      });
      await pumpReal(tester, adapter);
      await settleApp(tester);
      return ProviderScope.containerOf(tester.element(find.byType(App)));
    }

    String location(ProviderContainer c) =>
        c.read(routerProvider).state.uri.toString();

    Future<void> signInViaForm(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).first, 'esin');
      await tester.enterText(find.byType(TextFormField).last, 'x');
      await tester.tap(find.byType(FilledButton));
      await settleApp(tester);
    }

    testWidgets('sign out, then sign in, ends on the home page', (
      tester,
    ) async {
      final container = await pumpSignedIn(tester);
      expect(find.byType(ShellPage), findsOneWidget);
      await tester.runAsync(
        () => container.read(sessionProvider.notifier).logout(),
      );
      await tester.pumpAndSettle();
      expect(location(container), '/login');
      expect(find.byType(LoginPage), findsOneWidget);
      await signInViaForm(tester);
      expect(location(container), '/');
      expect(find.byType(ShellPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('reload on /login with a valid session shows the home page', (
      tester,
    ) async {
      final container = await pumpSignedIn(tester, route: '/login');
      expect(location(container), '/');
      expect(find.byType(ShellPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('sign-in with from=/login goes home, a valid from goes there', (
      tester,
    ) async {
      final container = await pumpSignedIn(
        tester,
        route: '/login?from=%2Flogin',
      );
      expect(location(container), '/');
      await tester.runAsync(
        () => container.read(sessionProvider.notifier).logout(),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/login?from=%2Fm%2Fcockpit');
      await tester.pumpAndSettle();
      await signInViaForm(tester);
      expect(location(container), '/m/cockpit');
    });

    testWidgets('refresh succeeds: /me is loaded and the shell is shown', (
      tester,
    ) async {
      final adapter = FakeAdapter((o) {
        if (o.path == '/auth/refresh') return tokenReply('t2');
        return _server(o);
      });
      await pumpReal(tester, adapter);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(adapter.count('/auth/refresh'), 1);
      // Startup /me plus the menu's /me (the menu is filtered by grants).
      expect(adapter.count('/me'), 2);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(ShellPage), findsOneWidget);
    });
  });
}
