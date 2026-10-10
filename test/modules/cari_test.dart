import 'dart:async';

import 'package:erp_shell/core/config/app_config.dart';
import 'package:erp_shell/core/l10n/generated/app_localizations.dart';
import 'package:erp_shell/core/l10n/generated/app_localizations_tr.dart';
import 'package:erp_shell/core/network/api_result.dart';
import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/core/theme/app_theme.dart';
import 'package:erp_shell/modules/cari/cari_messages.dart';
import 'package:erp_shell/modules/cari/cari_module.dart';
import 'package:erp_shell/modules/cari/data/cari_repository.dart';
import 'package:erp_shell/modules/cari/data/http_cari_repository.dart';
import 'package:erp_shell/modules/cari/data/mock_cari_repository.dart';
import 'package:erp_shell/modules/module_def.dart';
import 'package:erp_shell/shared/app_data_grid/grid_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trina_grid/trina_grid.dart';

import '../helpers/shell_harness.dart';

class _FakeContext implements ModuleContext {
  _FakeContext(this.permissions, {this.adresler});

  @override
  final ModulePermissions permissions;

  /// Permissions of the Adresler tab; defaults to the module's own.
  final ModulePermissions? adresler;

  @override
  ModulePermissions subPermissions(String name) => adresler ?? permissions;
  final dirtyChanges = <bool>[];
  final queries = <Map<String, String>>[];
  final _changes = StreamController<Map<String, String>>.broadcast();

  @override
  String get moduleKey => 'cari';
  @override
  String get title => 'Cariler';
  @override
  Map<String, String> get query => const {};
  @override
  Stream<Map<String, String>> get queryChanges => _changes.stream;
  @override
  void setQuery(Map<String, String> query) => queries.add(query);
  @override
  void setDirty(bool value) => dirtyChanges.add(value);
  @override
  void openModule(String moduleKey, {Map<String, String>? query}) {}
  @override
  void requestRefresh() {}
}

const _all = ModulePermissions(
  canView: true,
  canAdd: true,
  canEdit: true,
  canDelete: true,
);

final _l10n = AppLocalizationsTr();

Future<_FakeContext> _pump(
  WidgetTester tester,
  MockCariRepository repository, {
  ModulePermissions permissions = _all,
  // Default: a phone-sized window (cards, one form column, tall enough for
  // the form).
  Size size = const Size(500, 2600),
}) async {
  setWindowSize(tester, size);
  final ctx = _FakeContext(permissions);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(useMock: true, apiBaseUrl: '/api'),
        ),
        localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        cariRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: CariModule(ctx)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ctx;
}

bool _readOnly(WidgetTester tester, String label) => tester
    .widget<EditableText>(
      find.descendant(of: _field(label), matching: find.byType(EditableText)),
    )
    .readOnly;

Finder _field(String label) => find.widgetWithText(TextFormField, label);

/// On a phone the page actions are an icon button (primary) or in the
/// overflow menu.
Future<bool> _hasAction(WidgetTester tester, String label) async {
  if (find.byTooltip(label).evaluate().isNotEmpty) return true;
  final more = find.byTooltip(_l10n.moreActions);
  if (more.evaluate().isEmpty) return false;
  await tester.tap(more);
  await tester.pumpAndSettle();
  final found = find.text(label).evaluate().isNotEmpty;
  await tester.tapAt(const Offset(2, 2));
  await tester.pumpAndSettle();
  return found;
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  if (find.byTooltip(label).evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip(label));
  } else {
    await tester.tap(find.byTooltip(_l10n.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
  }
  await tester.pumpAndSettle();
}

Future<void> _openRecord(WidgetTester tester, String unvan) async {
  await tester.tap(find.text(unvan).first);
  await tester.pumpAndSettle();
}

void main() {
  group('GridQuery -> query parameters', () {
    test('page, size and the search text', () {
      final params = cariQueryParameters(
        const GridQuery(
          page: 3,
          pageSize: 50,
          filters: [GridFilter('arama', FilterOp.contains, ' bora ')],
        ),
      );
      expect(params, {'Page': 3, 'PageSize': 50, 'Arama': 'bora'});
    });

    test('role and inactive filters become their parameters', () {
      final params = cariQueryParameters(
        const GridQuery(
          filters: [
            GridFilter('musteri', FilterOp.eq, true),
            GridFilter('urunTedarikcisi', FilterOp.eq, true),
            GridFilter('hizmetTedarikcisi', FilterOp.eq, true),
            GridFilter('pasif', FilterOp.eq, true),
          ],
        ),
      );
      expect(params['CarininMusteriRoluVarMi'], true);
      expect(params['CarininUrunTedarikcisiRoluVarMi'], true);
      expect(params['CarininHizmetTedarikcisiRoluVarMi'], true);
      expect(params['PasifGoster'], true);
    });

    test('unticked filters, unknown filters and sorting are not sent', () {
      final params = cariQueryParameters(
        const GridQuery(
          sort: [GridSort('unvan')],
          filters: [
            GridFilter('musteri', FilterOp.eq, false),
            GridFilter('durum', FilterOp.eq, 'x'),
            GridFilter('arama', FilterOp.contains, '  '),
          ],
        ),
      );
      expect(params.keys, unorderedEquals(['Page', 'PageSize']));
    });

    test('page size is capped at 200, the search at 100 characters', () {
      final params = cariQueryParameters(
        GridQuery(
          pageSize: 100000,
          filters: [GridFilter('arama', FilterOp.contains, 'x' * 150)],
        ),
      );
      expect(params['PageSize'], 200);
      expect((params['Arama'] as String).length, 100);
    });
  });

  group('MessageCode -> field errors', () {
    ApiFailure<Object?> rule(int code) =>
        ApiFailure(httpStatus: 200, messageCode: code, message: 'sunucu');

    test('1002 marks the title', () {
      final view = mapCariFailure(_l10n, rule(1002));
      expect(view.fieldErrors.keys, [CariField.unvan]);
    });

    test('1201 marks the code', () {
      final view = mapCariFailure(_l10n, rule(1201));
      expect(view.fieldErrors, {CariField.kod: _l10n.apiMessage1201});
    });

    test('1202 marks tax no and national ID', () {
      final view = mapCariFailure(_l10n, rule(1202));
      expect(
        view.fieldErrors.keys,
        unorderedEquals([CariField.vergiNo, CariField.tcKimlikNo]),
      );
    });

    test('1004 goes back to the list, 1005 refreshes it', () {
      final notFound = mapCariFailure(_l10n, rule(1004));
      expect(notFound.notFound, isTrue);
      expect(notFound.message, _l10n.recordNotFound);
      final gone = mapCariFailure(_l10n, rule(1005));
      expect(gone.refreshList, isTrue);
      expect(gone.isInfo, isTrue);
    });

    test('1203-1205 are information messages', () {
      expect(mapCariFailure(_l10n, rule(1203)).message, _l10n.apiMessage1203);
      expect(mapCariFailure(_l10n, rule(1204)).message, _l10n.apiMessage1204);
      expect(mapCariFailure(_l10n, rule(1205)).message, _l10n.apiMessage1205);
      expect(mapCariFailure(_l10n, rule(1205)).isInfo, isTrue);
    });

    test('an unknown code shows the server message', () {
      final view = mapCariFailure(_l10n, rule(1999));
      expect(view.message, 'sunucu');
      expect(view.isInfo, isFalse);
    });
  });

  group('mock repository', () {
    test('about 60 records, some passive, some linked to Netsis', () async {
      final repo = MockCariRepository();
      final all = (await repo.list(
        const GridQuery(
          pageSize: 200,
          filters: [GridFilter('pasif', FilterOp.eq, true)],
        ),
      )).dataOrNull!;
      expect(all.total, 60);
      expect(all.items.where((c) => !c.aktif), isNotEmpty);
      expect(all.items.where((c) => c.netsisBagli), isNotEmpty);
      final active = (await repo.list(
        const GridQuery(pageSize: 200),
      )).dataOrNull!;
      expect(active.total, lessThan(60));
    });

    test('search is Turkish-insensitive; role filters narrow', () async {
      final repo = MockCariRepository();
      final found = (await repo.list(
        const GridQuery(
          filters: [GridFilter('arama', FilterOp.contains, 'ipek')],
        ),
      )).dataOrNull!;
      expect(found.items, isNotEmpty);
      expect(found.items.every((c) => c.unvan.contains('İpek')), isTrue);
      final customers = (await repo.list(
        const GridQuery(
          pageSize: 200,
          filters: [GridFilter('musteri', FilterOp.eq, true)],
        ),
      )).dataOrNull!;
      expect(customers.items.every((c) => c.musteri), isTrue);
    });
  });

  group('screens', () {
    testWidgets('expanded: the table draws the Netsis icon column', (
      tester,
    ) async {
      await _pump(tester, MockCariRepository(), size: const Size(2000, 900));
      // TrinaGrid (table) rather than cards, with real rows. Wide enough for
      // every column: the grid only builds the columns in view.
      expect(find.byType(TrinaGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Bora Tekstil Ltd. Şti.'), findsOneWidget);
      // Row 9 (and every 9th) is linked to Netsis: the link icon is drawn.
      expect(find.byIcon(Icons.link), findsWidgets);
    });

    testWidgets('list -> detail -> save -> delete with the mock repository', (
      tester,
    ) async {
      final repo = MockCariRepository();
      final ctx = await _pump(tester, repo);
      expect(await _hasAction(tester, 'Yeni'), isTrue);

      // List -> detail.
      await _openRecord(tester, 'Bora Tekstil Ltd. Şti.');
      expect(find.text('Cariler'), findsWidgets); // breadcrumb root
      final unvan = _field('Cari ünvanı *');
      expect(
        tester.widget<TextFormField>(unvan).controller!.text,
        'Bora Tekstil Ltd. Şti.',
      );

      // Edit -> dirty -> save.
      await tester.enterText(unvan, 'Bora Yeni Ünvan');
      await tester.pump();
      expect(ctx.dirtyChanges.last, isTrue);
      await _tapAction(tester, 'Kaydet');
      await tester.pumpAndSettle();
      expect(find.text('Kaydedildi'), findsOneWidget);
      expect(ctx.dirtyChanges.last, isFalse);
      expect((await repo.get(1)).dataOrNull!.unvan, 'Bora Yeni Ünvan');

      // Delete (confirm dialog).
      await _tapAction(tester, 'Sil');
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sil'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Silindi'), findsOneWidget);
      // Back on the list; the record is passive now and hidden.
      expect(find.text('Bora Yeni Ünvan'), findsNothing);
      expect((await repo.get(1)).dataOrNull!.aktif, isFalse);
    });

    testWidgets('new Cari: validation, then it is created and shown', (
      tester,
    ) async {
      final repo = MockCariRepository();
      await _pump(tester, repo);
      await _tapAction(tester, 'Yeni');
      await tester.pumpAndSettle();

      await _tapAction(tester, 'Kaydet');
      await tester.pumpAndSettle();
      expect(find.text('Bu alan zorunlu'), findsOneWidget);

      await tester.enterText(_field('Cari ünvanı *'), 'Yeni Firma A.Ş.');
      await tester.enterText(_field('Cari kodu'), 'X' * 16);
      await _tapAction(tester, 'Kaydet');
      await tester.pumpAndSettle();
      expect(find.text('En fazla 15 karakter girilebilir'), findsOneWidget);

      await tester.enterText(_field('Cari kodu'), 'YENI1');
      await _tapAction(tester, 'Kaydet');
      await tester.pumpAndSettle();
      expect(find.text('Kaydedildi'), findsOneWidget);
      // The saved Cari is shown with its id.
      final saved = (await repo.get(61)).dataOrNull!;
      expect(saved.unvan, 'Yeni Firma A.Ş.');
      expect(
        tester.widget<TextFormField>(_field('Cari kodu')).controller!.text,
        'YENI1',
      );
    });

    testWidgets('server rules show under the fields', (tester) async {
      final repo = MockCariRepository();
      await _pump(tester, repo);
      await _tapAction(tester, 'Yeni');
      await tester.pumpAndSettle();
      await tester.enterText(_field('Cari ünvanı *'), 'Çakışan');
      await tester.enterText(_field('Cari kodu'), 'C0001'); // taken
      await _tapAction(tester, 'Kaydet');
      await tester.pumpAndSettle();
      expect(find.text(_l10n.apiMessage1201), findsOneWidget);

      // Editing the field clears its error.
      await tester.enterText(_field('Cari kodu'), 'C9999');
      await tester.pumpAndSettle();
      expect(find.text(_l10n.apiMessage1201), findsNothing);

      await tester.enterText(_field('Vergi no'), '1000007919'); // taken
      await _tapAction(tester, 'Kaydet');
      await tester.pumpAndSettle();
      expect(find.text(_l10n.apiMessage1202), findsNWidgets(2));
    });

    testWidgets('a Cari linked to Netsis is read-only without Kaydet / Sil', (
      tester,
    ) async {
      final repo = MockCariRepository();
      await _pump(tester, repo);
      final linked = (await repo.get(9)).dataOrNull!;
      expect(linked.netsisBagli, isTrue);
      await tester.tap(find.text(linked.unvan).first);
      await tester.pumpAndSettle();
      expect(find.text(_l10n.cariNetsisReadonly), findsOneWidget);
      expect(await _hasAction(tester, 'Kaydet'), isFalse);
      expect(await _hasAction(tester, 'Sil'), isFalse);
      expect(_readOnly(tester, 'Cari ünvanı *'), isTrue);
    });

    testWidgets('a Cari that does not exist says so', (tester) async {
      final repo = MockCariRepository();
      final ctx = _FakeContext(_all);
      setWindowSize(tester, const Size(500, 2600));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(useMock: true, apiBaseUrl: '/api'),
            ),
            localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
            sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
            cariRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('tr'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: CariModule(_DeepLinkContext(ctx, {'id': '9999'})),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kayıt bulunamadı'), findsOneWidget);
    });

    testWidgets('buttons follow the permissions', (tester) async {
      final repo = MockCariRepository();
      await _pump(
        tester,
        repo,
        permissions: const ModulePermissions(canView: true),
      );
      expect(await _hasAction(tester, 'Yeni'), isFalse);
      await _openRecord(tester, 'Bora Tekstil Ltd. Şti.');
      expect(await _hasAction(tester, 'Kaydet'), isFalse);
      expect(await _hasAction(tester, 'Sil'), isFalse);
      expect(_readOnly(tester, 'Cari ünvanı *'), isTrue);
    });

    testWidgets('edit without delete permission hides Sil only', (
      tester,
    ) async {
      final repo = MockCariRepository();
      await _pump(
        tester,
        repo,
        permissions: const ModulePermissions(
          canView: true,
          canAdd: true,
          canEdit: true,
        ),
      );
      expect(await _hasAction(tester, 'Yeni'), isTrue);
      await _openRecord(tester, 'Bora Tekstil Ltd. Şti.');
      expect(await _hasAction(tester, 'Kaydet'), isTrue);
      expect(await _hasAction(tester, 'Sil'), isFalse);
    });
  });
}

/// A context that opens the module with a query (deep link).
class _DeepLinkContext extends _FakeContext {
  _DeepLinkContext(_FakeContext base, this._query)
    : super(base.permissions, adresler: base.adresler);

  final Map<String, String> _query;

  @override
  Map<String, String> get query => _query;
}
