import 'package:erp_shell/core/l10n/generated/app_localizations.dart';
import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/core/theme/app_theme.dart';
import 'package:erp_shell/core/utils/formatters.dart';
import 'package:erp_shell/shared/app_data_grid/app_data_grid.dart';
import 'package:erp_shell/shared/app_data_grid/csv_export.dart';
import 'package:erp_shell/shared/app_data_grid/grid_card_list.dart';
import 'package:erp_shell/shared/app_data_grid/grid_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trina_grid/trina_grid.dart';

import '../helpers/shell_harness.dart';

typedef _Row = ({int id, String ad, double tutar, DateTime tarih});

final _rows = <_Row>[
  for (var i = 1; i <= 30; i++)
    (
      id: i,
      ad: 'Kayıt $i',
      tutar: i * 1000.5,
      tarih: DateTime(2026, 1, i),
    ),
];

LocalGridDataSource<_Row> _source(List<_Row> rows) => LocalGridDataSource(
  rows,
  fieldValue: (r, f) => switch (f) {
    'id' => r.id,
    'ad' => r.ad,
    'tutar' => r.tutar,
    'tarih' => r.tarih,
    _ => null,
  },
);

final _columns = <AppGridColumn<_Row>>[
  AppGridColumn(field: 'ad', title: 'Ad', value: (r) => r.ad, cardTitle: true),
  AppGridColumn(
    field: 'tutar',
    title: 'Tutar',
    value: (r) => r.tutar,
    kind: GridColumnKind.money,
  ),
  AppGridColumn(
    field: 'tarih',
    title: 'Tarih',
    value: (r) => r.tarih,
    kind: GridColumnKind.date,
  ),
];

/// Records every query sent to the source.
class _RecordingSource implements GridDataSource<_Row> {
  final queries = <GridQuery>[];

  @override
  Future<GridPage<_Row>> fetch(GridQuery query) async {
    queries.add(query);
    return _source(_rows).apply(query);
  }
}

Future<void> _pumpGrid(
  WidgetTester tester,
  Size size,
  GridDataSource<_Row> source, {
  ValueChanged<_Row>? onOpen,
  KeyValueStore? store,
}) async {
  setWindowSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store ?? MemoryKeyValueStore()),
        sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: AppDataGrid<_Row>(
            gridId: 'test',
            moduleKey: 'm',
            columns: _columns,
            source: source,
            pageSize: 10,
            onOpen: onOpen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AppDataGrid', () {
    testWidgets('table on wide screens', (tester) async {
      await _pumpGrid(tester, const Size(1400, 900), _source(_rows));
      expect(find.byType(TrinaGrid), findsOneWidget);
      expect(find.byType(GridCardList<_Row>), findsNothing);
      expect(find.text('1–10 / 30'), findsOneWidget);
      // Values are formatted like the rest of the app.
      expect(find.text(Formatters.number(1000.5)), findsOneWidget);
      expect(find.text('01.01.2026'), findsOneWidget);
    });

    testWidgets('card list on phones; tap opens', (tester) async {
      _Row? opened;
      await _pumpGrid(
        tester,
        const Size(400, 800),
        _source(_rows),
        onOpen: (r) => opened = r,
      );
      expect(find.byType(TrinaGrid), findsNothing);
      expect(find.byType(GridCardList<_Row>), findsOneWidget);
      expect(find.text('Kayıt 1'), findsOneWidget);
      await tester.tap(find.text('Kayıt 1'));
      expect(opened?.id, 1);
    });

    testWidgets('pager requests the next page', (tester) async {
      final source = _RecordingSource();
      await _pumpGrid(tester, const Size(1400, 900), source);
      await tester.tap(find.byTooltip('Sonraki sayfa'));
      await tester.pumpAndSettle();
      expect(source.queries.last.page, 2);
      expect(find.text('11–20 / 30'), findsOneWidget);
    });

    testWidgets('phone sort menu sends a sort to the source', (tester) async {
      final source = _RecordingSource();
      await _pumpGrid(tester, const Size(400, 800), source);
      await tester.tap(find.text('Sırala'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tutar ↓'));
      await tester.pumpAndSettle();
      expect(source.queries.last.sort, [
        const GridSort('tutar', descending: true),
      ]);
      expect(source.queries.last.page, 1);
      expect(find.text('Kayıt 30'), findsOneWidget);
    });

    testWidgets('empty and error states', (tester) async {
      await _pumpGrid(tester, const Size(1400, 900), _source(const []));
      expect(find.text('Kayıt bulunamadı'), findsOneWidget);
    });
  });

  group('LocalGridDataSource', () {
    test('filters with Turkish folding, sorts and pages', () {
      final source = _source(_rows);
      final page = source.apply(
        const GridQuery(
          pageSize: 5,
          sort: [GridSort('tutar', descending: true)],
          filters: [GridFilter('ad', FilterOp.contains, 'KAYIT 1')],
        ),
      );
      // "Kayıt 1", "Kayıt 10".."Kayıt 19" match; highest amount first.
      expect(page.total, 11);
      expect(page.items.map((r) => r.id), [19, 18, 17, 16, 15]);
    });

    test('date range filters compare by day', () {
      final page = _source(_rows).apply(
        const GridQuery(
          filters: [
            GridFilter('tarih', FilterOp.gte, '2026-01-10'),
            GridFilter('tarih', FilterOp.lte, '2026-01-12'),
          ],
        ),
      );
      expect(page.items.map((r) => r.id), [10, 11, 12]);
    });
  });

  test('GridQuery JSON round trip (request body)', () {
    const query = GridQuery(
      page: 3,
      pageSize: 50,
      sort: [GridSort('tarih', descending: true)],
      filters: [GridFilter('durum', FilterOp.eq, 'Acik')],
    );
    expect(query.toJson(), {
      'page': 3,
      'pageSize': 50,
      'sort': [
        {'field': 'tarih', 'dir': 'desc'},
      ],
      'filters': [
        {'field': 'durum', 'op': 'eq', 'value': 'Acik'},
      ],
    });
    expect(GridQuery.fromJson(query.toJson()), query);
  });

  test('CSV uses ; separator, BOM, quoting and app formats', () {
    final csv = buildCsv(_columns, [
      (id: 1, ad: 'A; "B"', tutar: 1234.5, tarih: DateTime(2026, 3, 7)),
    ]);
    expect(csv, '﻿Ad;Tutar;Tarih\r\n"A; ""B""";1.234,50;07.03.2026\r\n');
  });

  test('GridPreferences order, save and load', () {
    final store = MemoryKeyValueStore();
    const prefs = GridPreferences(
      order: ['tarih', 'eski', 'ad'],
      widths: {'ad': 300},
      hidden: {'tutar'},
    );
    prefs.save(store, 'k');
    final loaded = GridPreferences.load(store, 'k');
    expect(loaded, prefs);
    // Unknown saved fields are ignored; new fields keep their place.
    expect(loaded.applyOrder(['ad', 'tutar', 'tarih']), [
      'tarih',
      'ad',
      'tutar',
    ]);
  });

  test('Formatters.tryParseNumber reads Turkish numbers', () {
    expect(Formatters.tryParseNumber('1.234,56'), 1234.56);
    expect(Formatters.tryParseNumber('12,5'), 12.5);
    expect(Formatters.tryParseNumber('1234'), 1234);
    expect(Formatters.tryParseNumber('abc'), isNull);
    expect(Formatters.tryParseNumber(''), isNull);
    expect(Formatters.editable(1234.5), '1234,5');
    expect(Formatters.editable(20), '20');
  });
}
