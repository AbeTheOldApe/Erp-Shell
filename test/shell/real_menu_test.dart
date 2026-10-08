import 'package:erp_shell/app.dart';
import 'package:erp_shell/core/config/app_config.dart';
import 'package:erp_shell/core/network/api_client.dart';
import 'package:erp_shell/core/router/app_router.dart';
import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/data/menu/menu_repository.dart';
import 'package:erp_shell/data/menu/mock_menu_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';

/// Real-mode shell: the menu comes from the client definition filtered by
/// the grants of `GET /me`.
void main() {
  late Map<String, Object?> me;
  late int thingsStatus;
  late FakeAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    me = meData(
      pages: ['CariMain'],
      buttons: {
        'CariMain': ['KAYDET'],
      },
    );
    thingsStatus = 200;
    adapter = FakeAdapter((o) {
      switch (o.path) {
        case '/auth/refresh':
          return tokenReply('t');
        case '/me':
          return FakeReply.ok(me);
        case '/things':
          return thingsStatus == 403
              ? FakeReply.fail(403, 2003, 'Yetki yok.')
              : FakeReply.ok({});
        default:
          return FakeReply.fail(404, 2004, 'Yok.');
      }
    });
  });

  Future<void> pumpReal(WidgetTester tester, {String? route}) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    if (route != null) {
      tester.platformDispatcher.defaultRouteNameTestValue = route;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(useMock: false, apiBaseUrl: 'http://localhost/api'),
          ),
          httpClientAdapterProvider.overrideWithValue(adapter),
          localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: const App(),
      ),
    );
    await settle(tester);
    container = ProviderScope.containerOf(tester.element(find.byType(App)));
  }

  Future<void> refreshFromUserMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Kullanıcı menüsü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menüyü yenile').last);
    await settle(tester);
  }

  testWidgets(
    'only granted pages are in the menu; Cari shows its permissions',
    (tester) async {
      await pumpReal(tester);
      expect(find.text('Tanımlar'), findsOneWidget);
      await tester.tap(find.text('Tanımlar'));
      await tester.pumpAndSettle();
      expect(find.text('Cariler'), findsOneWidget);
      expect(find.text('Siparişler'), findsNothing);

      await tester.tap(find.text('Cariler'));
      await settle(tester);
      expect(find.text('Görüntüleme'), findsOneWidget);
      // KAYDET gives add and edit; no SIL, so no delete.
      final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
      final granted = [
        for (final chip in chips)
          (
            (chip.label as Text).data,
            (chip.avatar! as Icon).icon == Icons.check_circle_outline,
          ),
      ];
      expect(granted, [
        ('Görüntüleme', true),
        ('Ekleme', true),
        ('Düzenleme', true),
        ('Silme', false),
      ]);
    },
  );

  testWidgets(
    'without the page the menu has no groups; the URL says no access',
    (tester) async {
      me = meData();
      await pumpReal(tester, route: '/m/cari');
      expect(find.text('Tanımlar'), findsNothing);
      expect(find.text('Yetkiniz yok'), findsOneWidget);
    },
  );

  testWidgets('"Menüyü yenile" calls /me and applies changed permissions', (
    tester,
  ) async {
    await pumpReal(tester);
    await tester.tap(find.text('Tanımlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cariler'));
    await settle(tester);
    expect(find.text('Silme'), findsOneWidget);

    final before = adapter.count('/me');
    me = meData(
      pages: ['CariMain'],
      buttons: {
        'CariMain': ['KAYDET', 'SIL'],
      },
    );
    await refreshFromUserMenu(tester);
    expect(adapter.count('/me'), before + 1);
    final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
    expect(
      chips.every(
        (c) => (c.avatar! as Icon).icon == Icons.check_circle_outline,
      ),
      isTrue,
    );

    // The page is revoked: the menu loses Cari and the open tab says so.
    me = meData();
    await refreshFromUserMenu(tester);
    expect(adapter.count('/me'), before + 2);
    expect(find.text('Tanımlar'), findsNothing);
    expect(find.text('Yetkiniz yok'), findsOneWidget);
  });

  testWidgets('a 403 warns on the open tab; the banner refreshes the menu', (
    tester,
  ) async {
    await pumpReal(tester);
    thingsStatus = 403;
    await tester.runAsync(
      () => container
          .read(apiClientProvider)
          .send<Object?>('GET', '/things', parse: (d) => d),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Yetkiniz değişmiş olabilir.'), findsOneWidget);

    final before = adapter.count('/me');
    await tester.tap(
      find.descendant(
        of: find.byType(MaterialBanner),
        matching: find.text('Menüyü yenile'),
      ),
    );
    await settle(tester);
    expect(adapter.count('/me'), before + 1);
    expect(find.textContaining('Yetkiniz değişmiş olabilir.'), findsNothing);
  });

  test('mock mode keeps the mock menu repository', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(useMock: true, apiBaseUrl: '/api'),
        ),
        localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(menuRepositoryProvider), isA<MockMenuRepository>());
    expect(container.read(routerProvider), isNotNull);
  });
}

/// Lets the fake HTTP answers (real async) arrive, then settles the UI.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}
