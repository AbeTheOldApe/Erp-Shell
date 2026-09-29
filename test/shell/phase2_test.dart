import 'dart:convert';

import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/core/storage/storage_keys.dart';
import 'package:erp_shell/shell/command_palette.dart';
import 'package:erp_shell/shell/personalization/recent_modules_controller.dart';
import 'package:erp_shell/shell/side_menu/side_menu_panel.dart';
import 'package:erp_shell/shell/tabs/shell_tab_bar.dart';
import 'package:erp_shell/shell/tabs/tab_item.dart';
import 'package:erp_shell/shell/tabs/tabs_notifier.dart';
import 'package:erp_shell/shell/tabs/tabs_persistence.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_harness.dart';

Finder _tab(String title) =>
    find.descendant(of: find.byType(ShellTabBar), matching: find.text(title));

Finder _inPanel(Finder finder) =>
    find.descendant(of: find.byType(SideMenuPanel), matching: finder);

Future<void> _open(WidgetTester tester, String group, String module) async {
  final leaf = _inPanel(find.text(module)).last;
  if (_inPanel(find.text(module)).evaluate().isEmpty) {
    await tester.tap(_inPanel(find.text(group)));
    await tester.pumpAndSettle();
  }
  await tester.tap(leaf);
  await tester.pumpAndSettle();
}

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  LogicalKeyboardKey? modifier,
}) async {
  if (modifier != null) await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  if (modifier != null) await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

/// Unmounts the app so the next [pumpApp] starts like a page reload.
Future<void> _reload(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  group('unit', () {
    test('TabsPersistence round trip skips pinned tabs', () {
      final persistence = TabsPersistence(MemoryKeyValueStore());
      persistence.save(
        1,
        const TabsState(
          tabs: [
            TabItem(moduleKey: 'cockpit', title: 'Cockpit', pinned: true),
            TabItem(moduleKey: 'stok', title: 'Stok'),
            TabItem(moduleKey: 'siparis', title: 'S', query: {'id': '7'}),
          ],
          activeKey: 'siparis',
        ),
      );
      final saved = persistence.load(1);
      expect(saved.map((t) => t.moduleKey), ['stok', 'siparis']);
      expect(saved.last.query, {'id': '7'});
      expect(persistence.load(2), isEmpty);
    });

    test('recent modules keep the last five, most recent first', () {
      final local = MemoryKeyValueStore();
      final session = MemoryKeyValueStore({
        StorageKeys.authTokens: jsonEncode({
          'accessToken': 'a',
          'refreshToken': 'r',
          'expiresAt': '2100-01-01T00:00:00.000',
          'user': {'id': 1, 'username': 'yonetici', 'displayName': 'Y'},
        }),
      });
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(local),
          sessionStoreProvider.overrideWithValue(session),
        ],
      );
      addTearDown(container.dispose);
      final recent = container.read(recentModulesProvider.notifier);
      for (final key in ['a', 'b', 'c', 'd', 'e', 'f', 'c']) {
        recent.touch(key);
      }
      expect(container.read(recentModulesProvider), ['c', 'f', 'e', 'd', 'b']);
      expect(
        jsonDecode(local.read(StorageKeys.recentModules(1))!),
        ['c', 'f', 'e', 'd', 'b'],
      );
    });
  });

  testWidgets('Cockpit cannot be closed', (tester) async {
    await pumpApp(tester);
    await _key(tester, LogicalKeyboardKey.keyW, modifier: LogicalKeyboardKey.altLeft);
    expect(_tab('Cockpit'), findsOneWidget);

    await _open(tester, 'Depo', 'Stok Durumu');
    await tester.tap(_tab('Cockpit'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Kapat'), findsNothing); // no "Kapat" for pinned tabs
    await tester.tap(find.text('Tümünü kapat'));
    await tester.pumpAndSettle();
    expect(_tab('Stok Durumu'), findsNothing);
    expect(_tab('Cockpit'), findsOneWidget);
  });

  testWidgets('open tabs come back after a reload (F5)', (tester) async {
    final session = MemoryKeyValueStore();
    await pumpApp(tester, sessionStore: session);
    await _open(tester, 'Depo', 'Stok Durumu');
    await _open(tester, 'Satış', 'Müşteriler');

    await _reload(tester);
    await pumpApp(tester, sessionStore: session);
    expect(_tab('Cockpit'), findsOneWidget);
    expect(_tab('Stok Durumu'), findsOneWidget);
    expect(_tab('Müşteriler'), findsOneWidget);
  });

  testWidgets('favorites: star, section, kept across sessions', (
    tester,
  ) async {
    final favorites = FakeFavoritesRepository();
    await pumpApp(tester, favorites: favorites);
    await tester.tap(_inPanel(find.text('Satış')));
    await tester.pumpAndSettle();
    await tester.tap(_inPanel(find.byTooltip('Favorilere ekle')).first);
    await tester.pumpAndSettle();

    expect(favorites.favorites, ['siparis']);
    expect(_inPanel(find.text('Favoriler')), findsOneWidget);
    expect(_inPanel(find.text('Siparişler')), findsNWidgets(2));

    await _reload(tester);
    await pumpApp(tester, favorites: favorites);
    expect(_inPanel(find.text('Favoriler')), findsOneWidget);

    await tester.tap(_inPanel(find.byTooltip('Favorilerden çıkar')).first);
    await tester.pumpAndSettle();
    expect(favorites.favorites, isEmpty);
    expect(_inPanel(find.text('Favoriler')), findsNothing);

    // A removal can be undone.
    expect(find.text('Siparişler favorilerden çıkarıldı'), findsOneWidget);
    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(favorites.favorites, ['siparis']);
    expect(_inPanel(find.text('Favoriler')), findsOneWidget);
  });

  testWidgets('command palette does not suggest the module on screen', (
    tester,
  ) async {
    await pumpApp(tester);
    await _open(tester, 'Depo', 'Stok Durumu');
    await _open(tester, 'Satış', 'Müşteriler');
    await _key(tester, LogicalKeyboardKey.keyK, modifier: LogicalKeyboardKey.controlLeft);
    final palette = find.byType(CommandPalette);
    expect(find.descendant(of: palette, matching: find.text('Stok Durumu')), findsOneWidget);
    expect(find.descendant(of: palette, matching: find.text('Müşteriler')), findsNothing);
  });

  testWidgets('recent modules are kept across sessions and shown in the '
      'command palette', (tester) async {
    final local = MemoryKeyValueStore();
    await pumpApp(tester, localStore: local);
    await _open(tester, 'Depo', 'Stok Durumu');
    await _open(tester, 'Satış', 'Müşteriler');

    await _reload(tester);
    await pumpApp(tester, localStore: local);
    await _key(tester, LogicalKeyboardKey.keyK, modifier: LogicalKeyboardKey.controlLeft);
    final palette = find.byType(CommandPalette);
    expect(find.descendant(of: palette, matching: find.text('Son kullanılanlar')), findsOneWidget);
    expect(find.descendant(of: palette, matching: find.text('Müşteriler')), findsOneWidget);
    expect(find.descendant(of: palette, matching: find.text('Stok Durumu')), findsOneWidget);
  });

  testWidgets('command palette: Ctrl+K, search, Enter opens the module', (
    tester,
  ) async {
    await pumpApp(tester);
    await _key(tester, LogicalKeyboardKey.keyK, modifier: LogicalKeyboardKey.controlLeft);
    expect(find.byType(CommandPalette), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byType(CommandPalette), matching: find.byType(TextField)),
      'MUSTERI',
    );
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(find.byType(CommandPalette), findsNothing);
    expect(_tab('Müşteriler'), findsOneWidget);
  });

  testWidgets('closing a dirty tab asks first', (tester) async {
    await pumpApp(tester);
    await _open(tester, 'Satış', 'Müşteriler');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await _key(tester, LogicalKeyboardKey.keyW, modifier: LogicalKeyboardKey.altLeft);
    expect(find.text('Kaydedilmemiş değişiklikler'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(_tab('Müşteriler'), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.keyW, modifier: LogicalKeyboardKey.altLeft);
    await tester.tap(find.text('Değişiklikleri at'));
    await tester.pumpAndSettle();
    expect(_tab('Müşteriler'), findsNothing);
  });

  testWidgets('sign-out in another browser tab signs this one out', (
    tester,
  ) async {
    final local = MemoryKeyValueStore();
    await pumpApp(tester, localStore: local);
    expect(_tab('Cockpit'), findsOneWidget);

    local.simulateExternalWrite(StorageKeys.logoutSignal, '1');
    await tester.pumpAndSettle();
    expect(find.text('Giriş yap'), findsOneWidget);
  });
}
