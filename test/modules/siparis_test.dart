import 'package:erp_shell/core/router/app_router.dart';
import 'package:erp_shell/data/mock/mock_backend.dart';
import 'package:erp_shell/modules/siparis/data/mock_siparis_repository.dart';
import 'package:erp_shell/modules/siparis/data/siparis_models.dart';
import 'package:erp_shell/modules/siparis/siparis_detail_page.dart';
import 'package:erp_shell/modules/siparis/siparis_list_page.dart';
import 'package:erp_shell/shared/app_data_grid/grid_card_list.dart';
import 'package:erp_shell/shared/app_data_grid/grid_query.dart';
import 'package:erp_shell/shell/side_menu/side_menu_panel.dart';
import 'package:erp_shell/shell/tabs/shell_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trina_grid/trina_grid.dart';

import '../helpers/shell_harness.dart';

Finder _inPanel(Finder f) =>
    find.descendant(of: find.byType(SideMenuPanel), matching: f);

Future<void> _openSiparis(WidgetTester tester) async {
  if (_inPanel(find.text('Siparişler')).evaluate().isEmpty) {
    await tester.tap(_inPanel(find.text('Satış')));
    await tester.pumpAndSettle();
  }
  await tester.tap(_inPanel(find.text('Siparişler')));
  await tester.pumpAndSettle();
}

/// Navigates like a link / typed URL.
Future<void> _go(WidgetTester tester, String location) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SideMenuPanel).first),
  );
  container.read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

Future<void> _openFirstOrderInTable(WidgetTester tester) async {
  final cell = find
      .descendant(of: find.byType(TrinaGrid), matching: find.textContaining('SP-'))
      .first;
  await tester.tap(cell);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

void main() {
  test('mock orders API: filter, sort and page like the contract', () async {
    final repo = MockSiparisRepository(
      backend: MockBackend(minLatency: Duration.zero, maxLatency: Duration.zero),
      accessToken: () => null,
    );
    // No token → 401, like the real API.
    expect(repo.query(const GridQuery()), throwsA(anything));

    final backend = MockBackend(
      minLatency: Duration.zero,
      maxLatency: Duration.zero,
    );
    final token = backend.login('yonetici')['accessToken'] as String;
    final authed = MockSiparisRepository(
      backend: backend,
      accessToken: () => token,
    );
    final page = await authed.query(
      const GridQuery(
        pageSize: 10,
        sort: [GridSort('tutar', descending: true)],
        filters: [GridFilter('durum', FilterOp.eq, 'Iptal')],
      ),
    );
    expect(page.items, hasLength(lessThanOrEqualTo(10)));
    expect(page.items.every((s) => s.durum == SiparisDurum.iptal), isTrue);
    for (var i = 1; i < page.items.length; i++) {
      expect(page.items[i - 1].tutar, greaterThanOrEqualTo(page.items[i].tutar));
    }

    final created = await authed.create(
      Siparis(
        musteri: 'Test',
        tarih: DateTime(2026, 9, 1),
        durum: SiparisDurum.acik,
        kalemler: const [
          SiparisKalemi(urun: 'Vida', miktar: 10, birimFiyat: 0.5),
        ],
      ),
    );
    expect(created.no, startsWith('SP-'));
    expect((await authed.get(created.id!)).tutar, 5);
    await authed.delete(created.id!);
    expect(authed.get(created.id!), throwsA(anything));
  });

  testWidgets('yonetici: list, open with double click, all buttons', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openSiparis(tester);
    expect(find.byType(SiparisListPage), findsOneWidget);
    expect(find.text('Yeni'), findsOneWidget);
    expect(find.textContaining('/ 137'), findsOneWidget);

    await _openFirstOrderInTable(tester);
    expect(find.byType(SiparisDetailPage), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);
    expect(find.text('Kalemler'), findsOneWidget);
  });

  testWidgets('depo (view only): no Yeni, no Kaydet, no Sil', (tester) async {
    await pumpApp(tester, username: 'depo');
    await _openSiparis(tester);
    expect(find.text('Yeni'), findsNothing);
    expect(find.text('Dışa aktar'), findsOneWidget);

    await _openFirstOrderInTable(tester);
    expect(find.byType(SiparisDetailPage), findsOneWidget);
    expect(find.text('Kaydet'), findsNothing);
    expect(find.text('Sil'), findsNothing);
    expect(find.text('Kalem ekle'), findsNothing);
    final musteri = tester.widget<TextField>(
      find.descendant(
        of: find.byType(SiparisDetailPage),
        matching: find.byType(TextField),
      ).first,
    );
    expect(musteri.readOnly, isTrue);
  });

  testWidgets('satis (no delete): Kaydet but no Sil', (tester) async {
    await pumpApp(tester, username: 'satis');
    await _openSiparis(tester);
    expect(find.text('Yeni'), findsOneWidget);
    await _openFirstOrderInTable(tester);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(find.text('Sil'), findsNothing);
  });

  testWidgets('closing the tab with a dirty form asks first', (tester) async {
    await pumpApp(tester);
    await _openSiparis(tester);
    await _openFirstOrderInTable(tester);

    final musteri = find.descendant(
      of: find.byType(SiparisDetailPage),
      matching: find.byType(TextField),
    ).first;
    await tester.enterText(musteri, 'Değişti A.Ş.');
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilmemiş değişiklikler'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ShellTabBar),
        matching: find.text('Siparişler'),
      ),
      findsOneWidget,
    );
    expect(find.text('Değişti A.Ş.'), findsOneWidget);
  });

  testWidgets('breadcrumb back to the list with a dirty form asks first', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openSiparis(tester);
    await _openFirstOrderInTable(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(SiparisDetailPage),
        matching: find.byType(TextField),
      ).first,
      'x',
    );
    await tester.pumpAndSettle();

    // Breadcrumb root: "Siparişler" (the one inside the detail page).
    await tester.tap(
      find.descendant(
        of: find.byType(SiparisDetailPage),
        matching: find.text('Siparişler'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Değişiklikleri at'));
    await tester.pumpAndSettle();
    expect(find.byType(SiparisDetailPage), findsNothing);
  });

  testWidgets('deep link ?id= opens the record; back to no query shows the '
      'list', (tester) async {
    await pumpApp(tester);
    await _go(tester, '/m/siparis?id=5');
    expect(find.byType(SiparisDetailPage), findsOneWidget);
    expect(find.text('SP-1005'), findsOneWidget);

    await _go(tester, '/m/siparis');
    expect(find.byType(SiparisDetailPage), findsNothing);
  });

  testWidgets('saving then going back with the browser refreshes the list', (
    tester,
  ) async {
    await pumpApp(tester);
    await _go(tester, '/m/siparis?id=5');
    await tester.enterText(
      find.descendant(
        of: find.byType(SiparisDetailPage),
        matching: find.byType(TextField),
      ).first,
      'Yeni Ad Ltd.',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    await _go(tester, '/m/siparis');
    expect(find.byType(SiparisDetailPage), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SiparisListPage),
        matching: find.text('Yeni Ad Ltd.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('unknown id shows "Kayıt bulunamadı"', (tester) async {
    await pumpApp(tester);
    await _go(tester, '/m/siparis?id=99999');
    expect(find.text('Kayıt bulunamadı'), findsOneWidget);
  });

  testWidgets('new order: validation, add line, save', (tester) async {
    await pumpApp(tester);
    await _openSiparis(tester);
    await tester.tap(find.text('Yeni'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sipariş'), findsWidgets);

    // Saving empty: required field and "at least one line".
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Bu alan zorunlu'), findsOneWidget);
    expect(find.text('En az bir kalem ekleyin'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(SiparisDetailPage),
        matching: find.byType(TextField),
      ).first,
      'Yeni Müşteri',
    );
    await tester.tap(find.text('Kalem ekle'));
    await tester.pumpAndSettle();
    final dialogFields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.at(0), 'Rulman');
    await tester.enterText(dialogFields.at(1), '2');
    await tester.enterText(dialogFields.at(2), '1.250,50');
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Kaydet')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Toplam: 2.501,00'), findsOneWidget);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Kaydedildi'), findsOneWidget);
    expect(find.text('SP-1138'), findsOneWidget);
  });

  testWidgets('phone: orders as cards, tap opens', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    await tester.tap(find.byTooltip('Menüyü aç/kapat'));
    await tester.pumpAndSettle();
    await _openSiparis(tester);
    expect(find.byType(GridCardList<SiparisOzet>), findsOneWidget);
    await tester.tap(find.textContaining('SP-').first);
    await tester.pumpAndSettle();
    expect(find.byType(SiparisDetailPage), findsOneWidget);
  });
}
