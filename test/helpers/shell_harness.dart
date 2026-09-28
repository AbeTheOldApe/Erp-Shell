import 'dart:convert';
import 'dart:io';

import 'package:erp_shell/app.dart';
import 'package:erp_shell/core/auth/auth_models.dart';
import 'package:erp_shell/core/config/app_config.dart';
import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/core/storage/storage_keys.dart';
import 'package:erp_shell/data/menu/menu_models.dart';
import 'package:erp_shell/data/menu/menu_repository.dart';
import 'package:erp_shell/data/mock/mock_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Menu repository returning the mock JSON of [username] without latency
/// or token checks.
class FakeMenuRepository implements MenuRepository {
  FakeMenuRepository(this.username);

  final String username;

  @override
  Future<List<MenuNode>> fetchMenu() async {
    final json = File('assets/mock/menu_$username.json').readAsStringSync();
    return parseMenuResponse(jsonDecode(json) as Map<String, dynamic>);
  }
}

/// Sets the logical window size for the test.
void setWindowSize(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Pumps the whole app, already signed in as [username] (or signed out).
///
/// With [useMockMenu] the real mock repositories and tokens are used (no
/// latency), so 401 / refresh flows behave as in the demo.
Future<void> pumpApp(
  WidgetTester tester, {
  String? username = 'yonetici',
  Size size = const Size(1400, 900),
  bool useMockMenu = false,
}) async {
  setWindowSize(tester, size);
  final backend = MockBackend(
    minLatency: Duration.zero,
    maxLatency: Duration.zero,
  );
  final session = MemoryKeyValueStore();
  if (username != null && useMockMenu) {
    session.write(
      StorageKeys.authTokens,
      jsonEncode(
        AuthSession.fromLoginResponse(
          backend.login(username),
          username: username,
        ).toJson(),
      ),
    );
  } else if (username != null) {
    final user = MockBackend.users[username]!;
    session.write(
      StorageKeys.authTokens,
      jsonEncode(
        AuthSession(
          accessToken: 'test',
          refreshToken: 'test',
          expiresAt: DateTime(2100),
          user: AppUser(
            id: user.id,
            username: username,
            displayName: user.displayName,
            roles: user.roles,
          ),
        ).toJson(),
      ),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(useMock: true, apiBaseUrl: '/api'),
        ),
        localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        sessionStoreProvider.overrideWithValue(session),
        mockBackendProvider.overrideWithValue(backend),
        if (username != null && !useMockMenu)
          menuRepositoryProvider.overrideWithValue(
            FakeMenuRepository(username),
          ),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}
