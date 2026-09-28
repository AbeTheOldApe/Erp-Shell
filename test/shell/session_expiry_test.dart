import 'package:erp_shell/shell/session_expired_dialog.dart';
import 'package:erp_shell/shell/side_menu/side_menu_panel.dart';
import 'package:erp_shell/shell/tabs/shell_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_harness.dart';

void main() {
  testWidgets('expired session keeps tabs and resumes after sign-in', (
    tester,
  ) async {
    await pumpApp(tester, useMockMenu: true);

    final panel = find.byType(SideMenuPanel);
    await tester.tap(find.descendant(of: panel, matching: find.text('Satış')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: panel, matching: find.text('Siparişler')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'yarım kalan iş');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kullanıcı menüsü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oturum süresini doldur'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionExpiredDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ShellTabBar),
        matching: find.text('Siparişler'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.descendant(
        of: find.byType(SessionExpiredDialog),
        matching: find.byType(TextField),
      ),
      '1234',
    );
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionExpiredDialog), findsNothing);
    expect(find.text('yarım kalan iş'), findsOneWidget);
  });
}
