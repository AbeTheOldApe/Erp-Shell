import 'dart:convert';
import 'dart:io';

import 'package:erp_shell/app.dart';
import 'package:erp_shell/core/auth/auth_models.dart';
import 'package:erp_shell/core/config/app_config.dart';
import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/core/storage/storage_keys.dart';
import 'package:erp_shell/data/favorites/favorites_repository.dart';
import 'package:erp_shell/data/menu/menu_models.dart';
import 'package:erp_shell/data/menu/menu_repository.dart';
import 'package:erp_shell/data/mock/mock_backend.dart';
import 'package:erp_shell/modules/registry.dart';
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

/// In-memory favorites API.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository([List<String>? initial]) : favorites = [...?initial];

  final List<String> favorites;

  @override
  Future<List<String>> fetchFavorites() async => [...favorites];

  @override
  Future<void> addFavorite(String moduleKey) async {
    if (!favorites.contains(moduleKey)) favorites.add(moduleKey);
  }

  @override
  Future<void> removeFavorite(String moduleKey) async =>
      favorites.remove(moduleKey);
}

/// Loads the code of every deferred module in the real zone. On the VM a
/// `loadLibrary()` first called inside one test's fake-async zone never
/// completes in later tests; once loaded, later calls complete at once.
Future<void> preloadDeferredModules(WidgetTester tester) => tester.runAsync(
  () => Future.wait([
    for (final def in moduleRegistry.values)
      if (def.load != null) def.load!(),
  ]),
);

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
  MemoryKeyValueStore? sessionStore,
  MemoryKeyValueStore? localStore,
  FavoritesRepository? favorites,
}) async {
  setWindowSize(tester, size);
  await preloadDeferredModules(tester);
  final backend = MockBackend(
    minLatency: Duration.zero,
    maxLatency: Duration.zero,
  );
  final session = sessionStore ?? MemoryKeyValueStore();
  // Real mock tokens, so module APIs (e.g. orders) accept them. A session
  // kept from an earlier pump (reload tests) is reused.
  if (username != null &&
      (useMockMenu || session.read(StorageKeys.authTokens) == null)) {
    session.write(
      StorageKeys.authTokens,
      jsonEncode(
        AuthSession.fromLoginResponse(
          backend.login(username),
          username: username,
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
        localStoreProvider.overrideWithValue(
          localStore ?? MemoryKeyValueStore(),
        ),
        sessionStoreProvider.overrideWithValue(session),
        mockBackendProvider.overrideWithValue(backend),
        if (username != null && !useMockMenu) ...[
          menuRepositoryProvider.overrideWithValue(
            FakeMenuRepository(username),
          ),
          favoritesRepositoryProvider.overrideWithValue(
            favorites ?? FakeFavoritesRepository(),
          ),
        ],
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}
