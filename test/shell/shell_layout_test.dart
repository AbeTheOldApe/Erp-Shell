import 'package:erp_shell/shell/side_menu/side_menu_panel.dart';
import 'package:erp_shell/shell/side_menu/side_menu_rail.dart';
import 'package:erp_shell/shell/tabs/open_modules_sheet.dart';
import 'package:erp_shell/shell/tabs/shell_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_harness.dart';

Finder _tabBarTab(String title) => find.descendant(
  of: find.byType(ShellTabBar),
  matching: find.text(title),
);

Future<void> _openFromPanel(
  WidgetTester tester,
  String group,
  String module,
) async {
  final panel = find.byType(SideMenuPanel);
  final leaf = find.descendant(of: panel, matching: find.text(module));
  if (leaf.evaluate().isEmpty) {
    await tester.tap(find.descendant(of: panel, matching: find.text(group)));
    await tester.pumpAndSettle();
  }
  await tester.tap(leaf);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the Cockpit as a pinned first tab after sign-in', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(_tabBarTab('Cockpit'), findsOneWidget);
    expect(
      find.text('Ana panel, modüller eklendikçe burada şekillenecek.'),
      findsOneWidget,
    );
    // Pinned: no close button on its tab.
    expect(
      find.descendant(
        of: find.byType(ShellTabBar),
        matching: find.byTooltip('Kapat'),
      ),
      findsNothing,
    );
  });

  testWidgets('expanded: full menu and tab bar', (tester) async {
    await pumpApp(tester, size: const Size(1400, 900));
    expect(find.byType(SideMenuPanel), findsOneWidget);
    expect(find.byType(SideMenuRail), findsNothing);
    expect(find.byType(ShellTabBar), findsOneWidget);
    expect(find.byType(OpenModulesButton), findsNothing);
  });

  testWidgets('medium: icon rail and tab bar', (tester) async {
    await pumpApp(tester, size: const Size(800, 900));
    expect(find.byType(SideMenuRail), findsOneWidget);
    expect(find.byType(SideMenuPanel), findsNothing);
    expect(find.byType(ShellTabBar), findsOneWidget);
  });

  testWidgets('compact: drawer menu and open modules button', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    expect(find.byType(SideMenuRail), findsNothing);
    expect(find.byType(SideMenuPanel), findsNothing);
    expect(find.byType(ShellTabBar), findsNothing);
    expect(find.byType(OpenModulesButton), findsOneWidget);

    await tester.tap(find.byTooltip('Menüyü aç/kapat'));
    await tester.pumpAndSettle();
    expect(find.byType(SideMenuPanel), findsOneWidget);
  });

  testWidgets('clicking the same module twice opens one tab', (tester) async {
    await pumpApp(tester);
    await _openFromPanel(tester, 'Satış', 'Müşteriler');
    await _openFromPanel(tester, 'Satış', 'Müşteriler');
    expect(_tabBarTab('Müşteriler'), findsOneWidget);
  });

  testWidgets('tabs and their state survive 1400 → 800 → 400 px', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1400, 900));
    await _openFromPanel(tester, 'Depo', 'Stok Durumu');
    await _openFromPanel(tester, 'Satış', 'Müşteriler');

    await tester.enterText(find.byType(TextField).last, 'taslak not');
    await tester.pumpAndSettle();

    setWindowSize(tester, const Size(800, 900));
    await tester.pumpAndSettle();
    expect(find.byType(SideMenuRail), findsOneWidget);
    expect(_tabBarTab('Stok Durumu'), findsOneWidget);
    expect(_tabBarTab('Müşteriler'), findsOneWidget);
    expect(find.text('taslak not'), findsOneWidget);

    setWindowSize(tester, const Size(400, 800));
    await tester.pumpAndSettle();
    expect(find.byType(ShellTabBar), findsNothing);
    expect(find.text('taslak not'), findsOneWidget);

    await tester.tap(find.byType(OpenModulesButton));
    await tester.pumpAndSettle();
    final sheet = find.byType(OpenModulesSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Stok Durumu')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Müşteriler')),
      findsOneWidget,
    );
  });

  testWidgets('keyboard shortcuts work after focus leaves a closed tab', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openFromPanel(tester, 'Depo', 'Stok Durumu');
    await _openFromPanel(tester, 'Satış', 'Müşteriler');
    // Focus a field in the active tab, then send that tab to the background
    // so the focused field is excluded and focus falls back to the route.
    await tester.enterText(find.byType(TextField).last, 'x');
    await tester.tap(_tabBarTab('Stok Durumu'));
    await tester.pumpAndSettle();

    Future<void> altKey(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
    }

    String title() => tester
        .widget<Text>(
          find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first,
        )
        .data!;

    // Tabs: Cockpit (pinned), Stok Durumu, Müşteriler.
    await altKey(LogicalKeyboardKey.digit3);
    expect(title(), 'Müşteriler');
    await altKey(LogicalKeyboardKey.arrowLeft);
    expect(title(), 'Stok Durumu');
    await altKey(LogicalKeyboardKey.arrowRight);
    expect(title(), 'Müşteriler');
    await altKey(LogicalKeyboardKey.keyW);
    expect(_tabBarTab('Müşteriler'), findsNothing);
    expect(title(), 'Stok Durumu');
  });

  testWidgets('menu differs per user', (tester) async {
    await pumpApp(tester, username: 'satis');
    final panel = find.byType(SideMenuPanel);
    expect(find.descendant(of: panel, matching: find.text('Satış')), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('Depo')), findsNothing);
    expect(find.descendant(of: panel, matching: find.text('Ayarlar')), findsNothing);
  });

  testWidgets('menu search uses Turkish folding', (tester) async {
    await pumpApp(tester);
    final panel = find.byType(SideMenuPanel);
    await tester.enterText(
      find.descendant(of: panel, matching: find.byType(TextField)),
      'SIPARIS',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: panel, matching: find.text('Siparişler')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('Stok Durumu')),
      findsNothing,
    );
  });

  testWidgets('signed-out users see the login page', (tester) async {
    await pumpApp(tester, username: null);
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('yonetici'), findsOneWidget);
  });
}
