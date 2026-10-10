import 'package:dio/dio.dart';
import 'package:erp_shell/core/auth/auth_models.dart';
import 'package:erp_shell/core/auth/permissions.dart';
import 'package:erp_shell/core/auth/session_controller.dart';
import 'package:erp_shell/core/config/app_config.dart';
import 'package:erp_shell/core/l10n/generated/app_localizations.dart';
import 'package:erp_shell/core/l10n/generated/app_localizations_tr.dart';
import 'package:erp_shell/core/network/api_client.dart';
import 'package:erp_shell/core/network/api_result.dart';
import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/core/theme/app_theme.dart';
import 'package:erp_shell/core/utils/decimal_units.dart';
import 'package:erp_shell/core/utils/formatters.dart';
import 'package:erp_shell/modules/cari/cari_belge_messages.dart';
import 'package:erp_shell/modules/cari/cari_module.dart';
import 'package:erp_shell/modules/cari/data/cari_belge_models.dart';
import 'package:erp_shell/modules/cari/data/cari_belge_repository.dart';
import 'package:erp_shell/modules/cari/data/cari_repository.dart';
import 'package:erp_shell/modules/cari/data/http_cari_belge_repository.dart';
import 'package:erp_shell/modules/cari/data/mock_cari_belge_repository.dart';
import 'package:erp_shell/modules/cari/data/mock_cari_repository.dart';
import 'package:erp_shell/modules/module_def.dart';
import 'package:erp_shell/modules/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/shell_harness.dart';

final _l10n = AppLocalizationsTr();

class _Context implements ModuleContext {
  _Context(this.permissions, {this.belgeler, this.query = const {}});

  @override
  final ModulePermissions permissions;
  final ModulePermissions? belgeler;
  @override
  final Map<String, String> query;
  final dirtyChanges = <bool>[];

  @override
  ModulePermissions subPermissions(String name) =>
      name == 'belgeler' ? (belgeler ?? permissions) : permissions;
  @override
  String get moduleKey => 'cari';
  @override
  String get title => 'Cariler';
  @override
  Stream<Map<String, String>> get queryChanges => const Stream.empty();
  @override
  void setQuery(Map<String, String> query) {}
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

/// Counts how often the option lists are fetched.
class _CountingRepository extends MockCariBelgeRepository {
  int optionCalls = 0;

  @override
  Future<ApiResult<BelgeSecenekleri>> secenekler() {
    optionCalls++;
    return super.secenekler();
  }
}

Future<_Context> _pump(
  WidgetTester tester, {
  required String id,
  IntegrationType type = IntegrationType.yok,
  ModulePermissions belgeler = _all,
  CariBelgeRepository? repository,
  Size size = const Size(500, 2600),
}) async {
  setWindowSize(tester, size);
  final ctx = _Context(_all, belgeler: belgeler, query: {'id': id});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(useMock: true, apiBaseUrl: '/api'),
        ),
        localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        cariRepositoryProvider.overrideWithValue(MockCariRepository()),
        cariBelgeRepositoryProvider.overrideWithValue(
          repository ?? MockCariBelgeRepository(),
        ),
        integrationTypeProvider.overrideWithValue(type),
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

Future<void> _openBelgeler(WidgetTester tester) async {
  await tester.tap(find.text('Belgeler'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _pick(WidgetTester tester, Key key, String name) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Kaydet').last);
  await tester.pumpAndSettle();
}

BelgeDraft _draft({
  int? tipi = 1,
  DateTime? tarih,
  int? doviz = 1,
  String no = '',
  List<KalemDraft>? kalemler,
  int? id,
}) => BelgeDraft(
  id: id,
  cariId: 1,
  tipiId: tipi,
  no: no,
  tarih: tarih ?? DateTime(2026, 10, 10),
  dovizId: doviz,
  kalemler: kalemler ?? const [KalemDraft(birimId: 1, tutar: '10')],
);

(HttpCariBelgeRepository, FakeAdapter) _http(
  FakeReply Function(RequestOptions) handler,
) {
  final adapter = FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
    ..httpClientAdapter = adapter;
  return (HttpCariBelgeRepository(ApiClient(dio)), adapter);
}

CariBelge _belge({
  int? id,
  List<BelgeKalem> kalemler = const [],
  DateTime? tarih,
}) => CariBelge(
  id: id,
  cariId: 5,
  tipiId: 1,
  no: ' B-1 ',
  tarih: tarih ?? DateTime(2026, 10, 10),
  dovizId: 1,
  vadeId: 1,
  kalemler: kalemler,
);

void main() {
  group('whole units instead of floating point', () {
    int units(String text, int decimals) =>
        parseUnits(text, decimals: decimals).value!;

    test('123,45 <-> 12345 kuruş', () {
      expect(units('123,45', 2), 12345);
      expect(formatUnits(12345, decimals: 2), '123,45');
      expect(units('1.234,5', 2), 123450);
      expect(formatUnits(123450, decimals: 2), '1.234,50');
      expect(editableUnits(123450, decimals: 2), '1234,5');
      expect(editableUnits(12300, decimals: 2), '123');
      expect(units('7', 2), 700);
      expect(units('0,05', 2), 5);
      expect(units('12,500', 2), 1250); // trailing zeros do not count
    });

    test('quantities in 1/10000', () {
      expect(units('1', 4), 10000);
      expect(units('2,5', 4), 25000);
      expect(units('0,0001', 4), 1);
      expect(formatUnits(25000, decimals: 4), '2,5000');
      expect(editableUnits(25000, decimals: 4), '2,5');
    });

    test('the total 133,55 has no floating point error', () {
      final total = sumKurus([units('123,45', 2), units('10,10', 2)]);
      expect(total, 13355);
      expect(formatUnits(total, decimals: 2), '133,55');
    });

    test('0,1 + 0,2 is exactly 0,3', () {
      final total = sumKurus([units('0,1', 2), units('0,2', 2)]);
      expect(total, 30);
      expect(formatUnits(total, decimals: 2), '0,30');
      expect(0.1 + 0.2, isNot(0.3));
    });

    test('empty amounts count 0 in the total', () {
      expect(sumKurus([100, null, 250]), 350);
    });

    test('too many decimals are an error, never rounded', () {
      expect(
        parseUnits('1,234', decimals: 2).error,
        UnitsError.tooManyDecimals,
      );
      expect(
        parseUnits('0,00001', decimals: 4).error,
        UnitsError.tooManyDecimals,
      );
    });

    test('bad input', () {
      expect(parseUnits('', decimals: 2).error, UnitsError.empty);
      expect(parseUnits('abc', decimals: 2).error, UnitsError.invalid);
      expect(parseUnits('1,2,3', decimals: 2).error, UnitsError.invalid);
      expect(parseUnits(',', decimals: 2).error, UnitsError.invalid);
      expect(
        parseUnits('99999999999999999999', decimals: 2).error,
        UnitsError.tooLarge,
      );
      expect(parseUnits('-5', decimals: 2).value, -500);
    });

    test('JSON numbers: written and read without drift', () {
      expect(unitsToJson(12345, decimals: 2), 123.45);
      expect(unitsToJson(25000, decimals: 4), 2.5);
      expect(unitsFromJson(123.45, decimals: 2), 12345);
      expect(unitsFromJson(10.1, decimals: 2), 1010);
      expect(unitsFromJson(133.55, decimals: 2), 13355);
      expect(unitsFromJson(1, decimals: 4), 10000);
      expect(unitsFromJson(null, decimals: 2), isNull);
    });
  });

  group('dates', () {
    test('sent as yyyy-MM-dd of the calendar day, shown as dd.MM.yyyy', () {
      final date = DateTime(2026, 10, 10);
      expect(isoDate(date), '2026-10-10');
      expect(Formatters.date(date), '10.10.2026');
      // Late and early in the day: no time zone can move the day.
      expect(isoDate(DateTime(2026, 1, 1, 23, 59, 59)), '2026-01-01');
      expect(isoDate(DateTime(2026, 12, 31, 0, 0, 1)), '2026-12-31');
      expect(isoDate(DateTime(987, 3, 4)), '0987-03-04');
    });

    test('parsing a day from the API', () {
      expect(parseIsoDate('2026-10-10'), DateTime(2026, 10, 10));
      expect(parseIsoDate('2026-02-30'), isNull);
      expect(parseIsoDate('10.10.2026'), isNull);
      expect(parseIsoDate(null), isNull);
    });

    test('the request carries the plain date text', () async {
      final (repo, adapter) = _http((_) => FakeReply.ok({'CariBelgeId': 1}));
      await repo.save(
        _belge(
          tarih: DateTime(2026, 10, 10, 23, 30),
          kalemler: [const BelgeKalem(birimId: 1, tutar: 100)],
        ),
        IntegrationType.yok,
      );
      expect(
        (adapter.requests.single.body! as Map)['CariBelgeTarihi'],
        '2026-10-10',
      );
    });
  });

  group('validation', () {
    BelgeValidation check(BelgeDraft draft) => validateBelge(draft);

    test('a valid document', () {
      expect(check(_draft()).isValid, isTrue);
      expect(check(_draft(no: 'x' * 20)).isValid, isTrue);
    });

    test('a new document needs a line; an existing one may have none', () {
      expect(check(_draft(kalemler: const [])).header, {
        BelgeField.form: BelgeIssue.atLeastOneKalem,
      });
      expect(check(_draft(id: 5, kalemler: const [])).isValid, isTrue);
    });

    test('type, date and currency are required; the number is limited', () {
      final draft = BelgeDraft(
        cariId: 1,
        no: 'x' * 21,
        kalemler: const [KalemDraft(birimId: 1, tutar: '1')],
      );
      expect(check(draft).header, {
        BelgeField.tipi: BelgeIssue.required,
        BelgeField.tarih: BelgeIssue.required,
        BelgeField.doviz: BelgeIssue.required,
        BelgeField.no: BelgeIssue.tooLong,
      });
    });

    test('amount: required, >= 0, at most 2 decimals', () {
      expect(checkTutar(''), BelgeIssue.required);
      expect(checkTutar('0'), isNull);
      expect(checkTutar('0,00'), isNull);
      expect(checkTutar('-1'), BelgeIssue.negative);
      expect(checkTutar('1,234'), BelgeIssue.tooManyDecimals);
      expect(checkTutar('1,23'), isNull);
      expect(checkTutar('abc'), BelgeIssue.invalidNumber);
      expect(checkTutar('1.234.567,89'), isNull);
    });

    test('quantity: > 0, at most 4 decimals', () {
      expect(checkMiktar('1'), isNull);
      expect(checkMiktar('0,0001'), isNull);
      expect(checkMiktar('0'), BelgeIssue.notPositive);
      expect(checkMiktar('-2'), BelgeIssue.notPositive);
      expect(checkMiktar('1,00001'), BelgeIssue.tooManyDecimals);
      expect(checkMiktar(''), BelgeIssue.required);
    });

    test('a line needs a unit; errors are per line', () {
      final result = check(
        _draft(
          kalemler: const [
            KalemDraft(birimId: 1, tutar: '5'),
            KalemDraft(miktar: '0', tutar: ''),
          ],
        ),
      );
      expect(result.rows[0], isEmpty);
      expect(result.rows[1], {
        KalemField.miktar: BelgeIssue.notPositive,
        KalemField.birim: BelgeIssue.required,
        KalemField.tutar: BelgeIssue.required,
      });
    });

    test('at most 200 lines', () {
      final lines = List.generate(
        201,
        (_) => const KalemDraft(birimId: 1, tutar: '1'),
      );
      expect(check(_draft(kalemler: lines)).header, {
        BelgeField.form: BelgeIssue.tooManyKalem,
      });
    });

    test('the document of a valid draft uses whole units', () {
      final belge = belgeFromDraft(
        _draft(
          no: ' A ',
          kalemler: const [
            KalemDraft(miktar: '2,5', birimId: 1, tutar: '10,10'),
          ],
        ),
      );
      expect(belge.no, 'A');
      expect(belge.kalemler.single.miktar, 25000);
      expect(belge.kalemler.single.tutar, 1010);
      expect(belge.toplamKurus, 1010);
    });
  });

  group('MessageCode -> view', () {
    ApiFailure<Object?> rule(int code, [String message = 'sunucu']) =>
        ApiFailure(httpStatus: 200, messageCode: code, message: message);

    test('1002 / 1003 point at the header field or the line', () {
      final view = mapBelgeFailure(
        _l10n,
        rule(1003),
        sent: _draft(
          kalemler: const [
            KalemDraft(birimId: 1, tutar: '1'),
            KalemDraft(birimId: 1, tutar: '1,234'),
          ],
        ),
      );
      expect(view.fieldErrors, isEmpty);
      expect(view.rowErrors.keys, [1]);
      expect(
        view.rowErrors[1]![KalemField.tutar],
        _l10n.validationMaxDecimals(2),
      );
      final header = mapBelgeFailure(
        _l10n,
        rule(1002),
        sent: _draft(kalemler: const []),
      );
      expect(header.fieldErrors, {BelgeField.form: _l10n.belgeKalemRequired});
    });

    test('1002 / 1003 the client cannot explain show the server text', () {
      final view = mapBelgeFailure(
        _l10n,
        rule(1003, 'Gecersiz vade.'),
        sent: _draft(),
      );
      expect(view.fieldErrors, {BelgeField.form: 'Gecersiz vade.'});
    });

    test('1004 and 1005 inform and refresh the list', () {
      final notFound = mapBelgeFailure(_l10n, rule(1004));
      expect(notFound.message, _l10n.recordNotFound);
      expect(notFound.isInfo && notFound.refreshList, isTrue);
      expect(
        mapBelgeFailure(_l10n, rule(1005)).message,
        _l10n.cariAlreadyDeleted,
      );
    });

    test('1203 does not exist for documents: server text', () {
      expect(mapBelgeFailure(_l10n, rule(1203)).message, _l10n.apiMessage1203);
      expect(mapBelgeFailure(_l10n, rule(1203)).refreshList, isFalse);
      expect(mapBelgeFailure(_l10n, rule(1999)).message, 'sunucu');
    });
  });

  group('sub-permission of the Belgeler tab', () {
    final sub = moduleRegistry['cari']!.subApi['belgeler']!;

    test('CariBelgeler is granted apart from CariMain and CariAdresler', () {
      const other = ApiGrants(
        pages: {'CariMain', 'CariAdresler'},
        buttons: {
          'CariMain': {'KAYDET', 'SIL'},
          'CariAdresler': {'KAYDET', 'SIL'},
        },
      );
      expect(sub.resolve(other), ModulePermissions.none);
      const grants = ApiGrants(
        pages: {'CariBelgeler'},
        buttons: {
          'CariBelgeler': {'KAYDET', 'SIL'},
        },
      );
      expect(sub.resolve(grants), _all);
      expect(sub.pageCode, 'CariBelgeler');
    });
  });

  group('HTTP repository', () {
    test('list: query, items and the total in kuruş', () async {
      final (repo, adapter) = _http(
        (_) => FakeReply.ok({
          'Items': [
            {
              'CariBelgeId': 29,
              'CariBelgeTipiId': 7,
              'CariBelgeTipi': 'Açılış',
              'Sign': 1,
              'CariBelgeNo': null,
              'CariBelgeTarihi': '2026-10-10',
              'DovizBirimiId': 1,
              'DovizBirimi': 'TRL',
              'OdemeVadeId': 1,
              'KalemSayisi': 2,
              'ToplamTutar': 133.55,
            },
          ],
          'TotalCount': 1,
          'Page': 2,
          'PageSize': 25,
        }),
      );
      final list = (await repo.list(5574, page: 2)).dataOrNull!;
      final request = adapter.requests.single;
      expect(request.path, '/fi/cari/5574/belgeler');
      expect(request.query, {'Page': 2, 'PageSize': 25});
      expect(list.total, 1);
      final item = list.items.single;
      expect(item.no, '');
      expect(item.tarih, DateTime(2026, 10, 10));
      expect(item.toplamKurus, 13355);
      expect(item.kalemSayisi, 2);
    });

    test('get: lines with units, an empty amount stays null', () async {
      final (repo, adapter) = _http(
        (_) => FakeReply.ok({
          'CariBelgeId': 29,
          'CariId': 5582,
          'CariBelgeTipiId': 7,
          'CariBelgeTipi': 'Eski',
          'CariBelgeNo': 'API-1',
          'CariBelgeTarihi': '2026-10-10',
          'DovizBirimiId': 1,
          'DovizBirimi': 'TRL',
          'OdemeVadeId': 1,
          'Kalemler': [
            {
              'CariBelgeKalemId': 51,
              'StokKartiId': 77,
              'Miktar': 2.5,
              'BirimId': 1,
              'Birim': 'Adet',
              'Tutar': 123.45,
            },
            {
              'CariBelgeKalemId': 52,
              'StokKartiId': null,
              'Miktar': 1.0,
              'BirimId': 1,
              'Birim': 'Adet',
              'Tutar': null,
            },
          ],
        }),
      );
      final belge = (await repo.get(29)).dataOrNull!;
      expect(adapter.requests.single.path, '/fi/cari-belge/29');
      expect(belge.tipi, 'Eski');
      expect(belge.kalemler[0].miktar, 25000);
      expect(belge.kalemler[0].tutar, 12345);
      expect(belge.kalemler[0].stokKartiId, 77);
      expect(belge.kalemler[1].tutar, isNull);
      expect(belge.kalemler[1].miktar, 10000);
    });

    test('save sends the whole line list with ids and JSON numbers', () async {
      final (repo, adapter) = _http((_) => FakeReply.ok({'CariBelgeId': 29}));
      final id = (await repo.save(
        _belge(
          id: 29,
          kalemler: const [
            BelgeKalem(id: 51, miktar: 10000, birimId: 1, tutar: 12345),
            BelgeKalem(miktar: 25000, birimId: 2, tutar: 1010),
          ],
        ),
        IntegrationType.yok,
      )).dataOrNull;
      expect(id, 29);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/fi/cari-belge');
      expect(request.body, {
        'CariBelgeId': 29,
        'CariId': 5,
        'CariBelgeTipiId': 1,
        'CariBelgeNo': 'B-1',
        'CariBelgeTarihi': '2026-10-10',
        'DovizBirimiId': 1,
        'OdemeVadeId': 1,
        'Kalemler': [
          {
            'CariBelgeKalemId': 51,
            'Miktar': 1.0,
            'BirimId': 1,
            'Tutar': 123.45,
          },
          {'Miktar': 2.5, 'BirimId': 2, 'Tutar': 10.1},
        ],
      });
    });

    test(
      'a new document has no CariBelgeId; no lines is an empty array',
      () async {
        final (repo, adapter) = _http((_) => FakeReply.ok({'CariBelgeId': 1}));
        await repo.save(_belge(), IntegrationType.yok);
        final body = adapter.requests.single.body! as Map;
        expect(body.containsKey('CariBelgeId'), isFalse);
        expect(body['Kalemler'], isEmpty);
      },
    );

    test('StokKartiId: never for Yok, kept for Netsis', () async {
      const lines = [
        BelgeKalem(id: 1, stokKartiId: 77, birimId: 1, tutar: 100),
        BelgeKalem(id: 2, birimId: 1, tutar: 100),
      ];
      final (repo, adapter) = _http((_) => FakeReply.ok({'CariBelgeId': 1}));
      await repo.save(_belge(id: 1, kalemler: lines), IntegrationType.yok);
      await repo.save(_belge(id: 1, kalemler: lines), IntegrationType.netsis);
      List<Map<String, dynamic>> sent(int i) => [
        for (final k in (adapter.requests[i].body! as Map)['Kalemler'] as List)
          k as Map<String, dynamic>,
      ];
      expect(sent(0).every((k) => !k.containsKey('StokKartiId')), isTrue);
      expect(sent(1)[0]['StokKartiId'], 77);
      expect(sent(1)[1].containsKey('StokKartiId'), isFalse);
    });

    test('delete and the option lists', () async {
      final (repo, adapter) = _http((o) {
        if (o.path == '/fi/cari-belge-secenekleri') {
          return FakeReply.ok({
            'BelgeTipleri': [
              {'CariBelgeTipiId': 1, 'CariBelgeTipi': 'Satış', 'Sign': 1},
            ],
            'DovizBirimleri': [
              {
                'DovizBirimiId': 1,
                'DovizBirimi': 'TRL',
                'DovizBirimiTanimi': 'TÜRK LİRASI',
                'DovizSimgesi': '₺',
              },
            ],
            'Birimler': [
              {'BirimId': 1, 'Birim': 'Adet', 'BirimKodu': 'AD'},
            ],
            'Vadeler': [
              {'OdemeVadeId': 1, 'OdemeVade': 'Peşin', 'OdemeVadeGunSayisi': 0},
            ],
          });
        }
        return FakeReply.ok({'CariBelgeId': 3});
      });
      expect((await repo.delete(3)).isSuccess, isTrue);
      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.path, '/fi/cari-belge/3');
      final options = (await repo.secenekler()).dataOrNull!;
      expect(options.tipler.single.ad, 'Satış');
      expect(options.dovizler.single.kod, 'TRL');
      expect(options.birimler.single.ad, 'Adet');
      expect(options.vadeler.single.ad, 'Peşin');
      expect(options.varsayilanDoviz!.id, 1);
      expect(options.varsayilanBirim!.ad, 'Adet');
    });
  });

  group('mock repository', () {
    test(
      'seed: single-line, multi-line, line-less and inactive-type',
      () async {
        final repo = MockCariBelgeRepository();
        final list = (await repo.list(1)).dataOrNull!;
        expect(list.total, 4);
        final counts = list.items.map((b) => b.kalemSayisi).toList();
        expect(counts, containsAll([0, 1, 3]));
        expect(list.items.any((b) => b.tipi == 'Eski Fatura'), isTrue);
        // Newest first.
        final dates = list.items.map((b) => b.tarih).toList();
        expect(dates, [...dates]..sort((a, b) => b.compareTo(a)));
        // The total adds the amounts; quantities do not multiply them.
        final multi = list.items.firstWhere((b) => b.kalemSayisi == 3);
        expect(multi.toplamKurus, 10010 + 3333 + 0);
      },
    );

    test('add -> list -> edit (delete and add a line) -> delete', () async {
      final repo = MockCariBelgeRepository();
      final before = (await repo.list(1)).dataOrNull!.total;

      final id = (await repo.save(
        CariBelge(
          cariId: 1,
          tipiId: 1,
          tarih: DateTime(2026, 5, 5),
          dovizId: 1,
          kalemler: const [BelgeKalem(birimId: 1, tutar: 1000)],
        ),
        IntegrationType.yok,
      )).dataOrNull!;
      expect((await repo.list(1)).dataOrNull!.total, before + 1);

      var saved = (await repo.get(id)).dataOrNull!;
      final keptId = saved.kalemler.single.id;
      expect(keptId, isNotNull);

      // Replace the line list: the old line is dropped, a new one added.
      await repo.save(
        CariBelge(
          id: id,
          cariId: 1,
          tipiId: 1,
          tarih: saved.tarih,
          dovizId: 1,
          kalemler: const [
            BelgeKalem(miktar: 20000, birimId: 2, tutar: 550),
            BelgeKalem(miktar: 10000, birimId: 1, tutar: 450),
          ],
        ),
        IntegrationType.yok,
      );
      saved = (await repo.get(id)).dataOrNull!;
      expect(saved.kalemler.length, 2);
      expect(saved.kalemler.any((k) => k.id == keptId), isFalse);
      expect(saved.toplamKurus, 1000);

      // Without lines: allowed for an existing document.
      await repo.save(
        CariBelge(id: id, cariId: 1, tipiId: 1, tarih: saved.tarih, dovizId: 1),
        IntegrationType.yok,
      );
      expect((await repo.get(id)).dataOrNull!.kalemler, isEmpty);

      expect((await repo.delete(id)).isSuccess, isTrue);
      expect((await repo.list(1)).dataOrNull!.total, before);
      expect((await repo.get(id)).failureOrNull!.messageCode, 1004);
      expect((await repo.delete(id)).failureOrNull!.messageCode, 1005);
    });

    test('paging: 60 documents, 25 per page', () async {
      final repo = MockCariBelgeRepository();
      final p1 = (await repo.list(3)).dataOrNull!;
      expect(p1.total, 60);
      expect(p1.items.length, 25);
      final p3 = (await repo.list(3, page: 3)).dataOrNull!;
      expect(p3.items.length, 10);
      final ids = {
        ...p1.items.map((b) => b.id),
        ...(await repo.list(3, page: 2)).dataOrNull!.items.map((b) => b.id),
        ...p3.items.map((b) => b.id),
      };
      expect(ids.length, 60);
    });

    test('a new document needs a line; server rules', () async {
      final repo = MockCariBelgeRepository();
      Future<int> codeOf(CariBelge b) async =>
          (await repo.save(b, IntegrationType.yok)).failureOrNull!.messageCode;
      expect(await codeOf(_belge()), 1002);
      expect(
        await codeOf(
          _belge(kalemler: const [BelgeKalem(birimId: 99, tutar: 1)]),
        ),
        1003,
      );
      expect(
        await codeOf(
          CariBelge(
            cariId: 1,
            tipiId: 99, // inactive: a new document cannot use it
            tarih: DateTime(2026, 1, 1),
            dovizId: 1,
            kalemler: const [BelgeKalem(birimId: 1, tutar: 1)],
          ),
        ),
        1003,
      );
    });

    test('an inactive type is kept, but cannot be chosen', () async {
      final repo = MockCariBelgeRepository();
      final old = (await repo.list(
        1,
      )).dataOrNull!.items.firstWhere((b) => b.tipi == 'Eski Fatura');
      final belge = (await repo.get(old.id)).dataOrNull!;
      expect(belge.tipi, 'Eski Fatura');
      final options = (await repo.secenekler()).dataOrNull!;
      expect(options.tipler.any((t) => t.id == belge.tipiId), isFalse);
      // Saved as it is: fine.
      expect((await repo.save(belge, IntegrationType.yok)).isSuccess, isTrue);
      expect((await repo.get(old.id)).dataOrNull!.tipiId, belge.tipiId);
    });

    test('the stock card: only the Netsis set writes it', () async {
      final repo = MockCariBelgeRepository();
      final id = (await repo.list(9)).dataOrNull!.items.single.id;
      final belge = (await repo.get(id)).dataOrNull!;
      expect(belge.kalemler.single.stokKartiId, 4242);

      final withoutStock = CariBelge(
        id: id,
        cariId: 9,
        tipiId: belge.tipiId,
        tarih: belge.tarih,
        dovizId: 1,
        kalemler: [
          BelgeKalem(id: belge.kalemler.single.id, birimId: 1, tutar: 100),
        ],
      );
      // Yok: ignored, the stored value stays.
      await repo.save(withoutStock, IntegrationType.yok);
      expect(
        (await repo.get(id)).dataOrNull!.kalemler.single.stokKartiId,
        4242,
      );
      // Netsis: not sent means cleared.
      await repo.save(withoutStock, IntegrationType.netsis);
      expect(
        (await repo.get(id)).dataOrNull!.kalemler.single.stokKartiId,
        isNull,
      );
    });
  });

  group('option lists per session', () {
    test('fetched once, dropped when the user changes', () async {
      final repo = _CountingRepository();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(useMock: true, apiBaseUrl: '/api'),
          ),
          localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          cariBelgeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(belgeSeceneklerProvider, (_, _) {});
      addTearDown(listener.close);

      final first = await container.read(belgeSeceneklerProvider.future);
      await container.read(belgeSeceneklerProvider.future);
      expect(first.tipler, isNotEmpty);
      expect(repo.optionCalls, 1);

      await container.read(sessionProvider.notifier).login('satis', '1234');
      await container.read(belgeSeceneklerProvider.future);
      expect(repo.optionCalls, 2);
    });

    testWidgets('opening the form twice asks the API once', (tester) async {
      final repo = _CountingRepository();
      await _pump(tester, id: '1', repository: repo);
      await _openBelgeler(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Yeni belge'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Kapat'));
        await tester.pumpAndSettle();
      }
      expect(repo.optionCalls, 1);
    });
  });

  group('screen', () {
    testWidgets('list: date, type, number, currency, lines, total', (
      tester,
    ) async {
      await _pump(tester, id: '1');
      await _openBelgeler(tester);
      // Cards on a phone, newest first.
      expect(find.text('15.03.2026 · Satış Faturası'), findsOneWidget);
      expect(find.textContaining('F-100'), findsOneWidget);
      expect(find.text('133,43 USD'), findsOneWidget);
      // No number: a dash.
      expect(find.textContaining('${_l10n.belgeColNo}: -'), findsOneWidget);
      expect(find.text('123,45 TRL'), findsOneWidget);
    });

    testWidgets('wide: a table with the columns', (tester) async {
      await _pump(tester, id: '1', size: const Size(1200, 900));
      await _openBelgeler(tester);
      for (final label in [
        _l10n.belgeColTarih,
        _l10n.belgeColTipi,
        _l10n.belgeColNo,
        _l10n.belgeColDoviz,
        _l10n.belgeColKalem,
        _l10n.belgeColToplam,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('15.03.2026'), findsOneWidget);
      expect(find.text('133,43'), findsOneWidget);
    });

    testWidgets('an empty list shows the empty state', (tester) async {
      await _pump(tester, id: '2');
      await _openBelgeler(tester);
      expect(find.text(_l10n.belgeEmpty), findsOneWidget);
    });

    testWidgets('paging asks the server for the next page', (tester) async {
      await _pump(tester, id: '3', size: const Size(500, 4000));
      await _openBelgeler(tester);
      expect(find.text(_l10n.gridRange('1', '25', '60')), findsOneWidget);
      await tester.tap(find.byTooltip(_l10n.gridNextPage));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.gridRange('26', '50', '60')), findsOneWidget);
      await tester.tap(find.byTooltip(_l10n.gridNextPage));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.gridRange('51', '60', '60')), findsOneWidget);
    });

    testWidgets('buttons follow the sub-permissions', (tester) async {
      Future<void> check(
        ModulePermissions p, {
        required bool add,
        required bool delete,
      }) async {
        await _pump(tester, id: '1', belgeler: p);
        await _openBelgeler(tester);
        expect(find.text('Yeni belge'), add ? findsOneWidget : findsNothing);
        expect(find.byTooltip('Sil'), delete ? findsWidgets : findsNothing);
        // The documents themselves are always listed.
        expect(find.textContaining('F-100'), findsOneWidget);
      }

      await check(
        const ModulePermissions(canView: true),
        add: false,
        delete: false,
      );
      await check(
        const ModulePermissions(canView: true, canAdd: true),
        add: true,
        delete: false,
      );
      await check(
        const ModulePermissions(canView: true, canEdit: true),
        add: false,
        delete: false,
      );
      await check(
        const ModulePermissions(canView: true, canDelete: true),
        add: false,
        delete: true,
      );
    });

    testWidgets('no tab without the Belgeler permission', (tester) async {
      await _pump(tester, id: '1', belgeler: ModulePermissions.none);
      expect(find.text('Cari ünvanı *'), findsOneWidget);
      expect(find.text('Belgeler'), findsNothing);
    });

    testWidgets('a new Cari: the tab is disabled and explained', (
      tester,
    ) async {
      await _pump(tester, id: 'yeni');
      expect(find.text(_l10n.belgeSaveFirst), findsOneWidget);
      final button = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(button.segments.last.value, 2);
      expect(button.segments.last.enabled, isFalse);
      await tester.tap(find.text('Belgeler'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Yeni belge'), findsNothing);
    });

    testWidgets('a saved Cari enables the tab', (tester) async {
      await _pump(tester, id: 'yeni');
      await tester.enterText(_field('Cari ünvanı *'), 'Yeni Firma A.Ş.');
      await tester.tap(find.byTooltip('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.belgeSaveFirst), findsNothing);
      final button = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(button.segments.last.enabled, isTrue);
    });

    testWidgets('a Netsis-linked Cari: buttons by permission, not read-only', (
      tester,
    ) async {
      await _pump(tester, id: '9', type: IntegrationType.netsis);
      await _openBelgeler(tester);
      expect(find.text('Yeni belge'), findsOneWidget);
      expect(find.byTooltip('Sil'), findsWidgets);
      expect(find.text(_l10n.cariNetsisReadonly), findsNothing);

      await tester.tap(find.byTooltip('Sil').first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      // Without permissions the same buttons are gone.
      await _pump(
        tester,
        id: '9',
        type: IntegrationType.netsis,
        belgeler: const ModulePermissions(canView: true),
      );
      await _openBelgeler(tester);
      expect(find.text('Yeni belge'), findsNothing);
      expect(find.byTooltip('Sil'), findsNothing);
    });

    testWidgets('new document: validation, then it is saved', (tester) async {
      final repo = MockCariBelgeRepository();
      await _pump(tester, id: '2', repository: repo);
      await _openBelgeler(tester);
      await tester.tap(find.text('Yeni belge'));
      await tester.pumpAndSettle();

      // The form starts with one line, unit Adet, quantity 1.
      expect(
        tester.widget<TextFormField>(_field('Miktar *')).controller!.text,
        '1',
      );
      expect(find.text('Adet'), findsOneWidget);

      await _save(tester);
      // Type and amount.
      expect(find.text(_l10n.validationRequired), findsNWidgets(2));

      await _pick(tester, const ValueKey('belge-tipi'), 'Satış Faturası');
      await tester.enterText(_field('Tutar *'), '1,234');
      await _save(tester);
      expect(find.text(_l10n.validationMaxDecimals(2)), findsOneWidget);

      await tester.enterText(_field('Tutar *'), '1.234,50');
      await tester.enterText(_field('Belge no'), 'X-1');
      await _save(tester);
      expect(find.text('Kaydedildi'), findsOneWidget);
      final saved = (await repo.list(2)).dataOrNull!.items.single;
      expect(saved.no, 'X-1');
      expect(saved.toplamKurus, 123450);
      expect(saved.dovizKodu, 'TRL');
    });

    testWidgets('a new document needs a line', (tester) async {
      await _pump(tester, id: '2');
      await _openBelgeler(tester);
      await tester.tap(find.text('Yeni belge'));
      await tester.pumpAndSettle();
      await _pick(tester, const ValueKey('belge-tipi'), 'Açılış');
      await tester.tap(find.byTooltip(_l10n.belgeKalemSil));
      await tester.pumpAndSettle();
      await _save(tester);
      expect(find.text(_l10n.belgeKalemRequired), findsOneWidget);
    });

    testWidgets('edit: delete a line, add one, save', (tester) async {
      final repo = MockCariBelgeRepository();
      await _pump(tester, id: '1', repository: repo);
      await _openBelgeler(tester);
      await tester.tap(find.text('15.03.2026 · Satış Faturası'));
      await tester.pumpAndSettle();

      // The three lines of the document, with their amounts.
      expect(find.byTooltip(_l10n.belgeKalemSil), findsNWidgets(3));
      expect(
        tester.widget<TextFormField>(_field('Tutar *').at(0)).controller!.text,
        '100,1',
      );
      expect(find.text('${_l10n.belgeToplam}: 133,43 USD'), findsOneWidget);

      await tester.tap(find.byTooltip(_l10n.belgeKalemSil).at(1));
      await tester.pumpAndSettle();
      expect(find.byTooltip(_l10n.belgeKalemSil), findsNWidgets(2));
      expect(find.text('${_l10n.belgeToplam}: 100,10 USD'), findsOneWidget);

      await tester.tap(find.text(_l10n.belgeKalemEkle));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Tutar *').last, '5,5');
      await tester.pump();
      expect(find.text('${_l10n.belgeToplam}: 105,60 USD'), findsOneWidget);
      await _save(tester);
      expect(find.text('Kaydedildi'), findsOneWidget);

      final id = (await repo.list(
        1,
      )).dataOrNull!.items.firstWhere((b) => b.no == 'F-100').id;
      final saved = (await repo.get(id)).dataOrNull!;
      expect(saved.kalemler.length, 3);
      expect(saved.toplamKurus, 10010 + 0 + 550);
      expect(saved.kalemler.last.tutar, 550);
    });

    testWidgets('the last line of an existing document can go, with a note', (
      tester,
    ) async {
      final repo = MockCariBelgeRepository();
      await _pump(tester, id: '1', repository: repo);
      await _openBelgeler(tester);
      await tester.tap(find.textContaining('02.01.2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_l10n.belgeKalemSil));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.belgeNoKalemInfo), findsWidgets);
      await _save(tester);
      expect(find.text('Kaydedildi'), findsOneWidget);
      final id = (await repo.list(
        1,
      )).dataOrNull!.items.firstWhere((b) => b.no == 'A-1').id;
      expect((await repo.get(id)).dataOrNull!.kalemler, isEmpty);
    });

    testWidgets('without edit permission the document opens read-only', (
      tester,
    ) async {
      await _pump(
        tester,
        id: '1',
        belgeler: const ModulePermissions(canView: true),
      );
      await _openBelgeler(tester);
      await tester.tap(find.text('15.03.2026 · Satış Faturası'));
      await tester.pumpAndSettle();
      expect(find.text('Kaydet'), findsNothing);
      expect(find.text(_l10n.belgeKalemEkle), findsNothing);
      expect(find.byTooltip(_l10n.belgeKalemSil), findsNothing);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: _field('Belge no'),
                matching: find.byType(EditableText),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(find.text('F-100'), findsOneWidget);
    });

    testWidgets('an inactive type is shown and kept; others cannot return', (
      tester,
    ) async {
      final repo = MockCariBelgeRepository();
      await _pump(tester, id: '1', repository: repo);
      await _openBelgeler(tester);
      await tester.tap(find.textContaining('31.12.2025'));
      await tester.pumpAndSettle();
      // The inactive type is the current value.
      expect(find.text('Eski Fatura'), findsOneWidget);

      // Saved unchanged: stays in that type.
      await _save(tester);
      expect(find.text('Kaydedildi'), findsOneWidget);
      final old = (await repo.list(
        1,
      )).dataOrNull!.items.firstWhere((b) => b.tipi == 'Eski Fatura');
      expect(old.tipi, 'Eski Fatura');

      // Open again, switch to an active type: the old one is gone from the
      // choices.
      await tester.tap(find.textContaining('31.12.2025'));
      await tester.pumpAndSettle();
      await _pick(tester, const ValueKey('belge-tipi'), 'Tahsilat');
      await tester.tap(find.byKey(const ValueKey('belge-tipi')));
      await tester.pumpAndSettle();
      expect(find.text('Eski Fatura'), findsNothing);
    });

    testWidgets('the stock card shows read-only in the Netsis set only', (
      tester,
    ) async {
      final repo = MockCariBelgeRepository();
      await _pump(
        tester,
        id: '9',
        type: IntegrationType.netsis,
        repository: repo,
      );
      await _openBelgeler(tester);
      await tester.tap(find.textContaining('04.04.2026'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.belgeStokKarti(4242)), findsOneWidget);
      // Saved as it is: the stock card is sent back and kept.
      await _save(tester);
      final id = (await repo.list(9)).dataOrNull!.items.single.id;
      expect(
        (await repo.get(id)).dataOrNull!.kalemler.single.stokKartiId,
        4242,
      );
    });

    testWidgets('the Yok set never shows the stock card', (tester) async {
      await _pump(tester, id: '9');
      await _openBelgeler(tester);
      await tester.tap(find.textContaining('04.04.2026'));
      await tester.pumpAndSettle();
      expect(find.textContaining('4242'), findsNothing);
    });

    testWidgets('a changed form asks before closing', (tester) async {
      final ctx = await _pump(tester, id: '1');
      await _openBelgeler(tester);
      await tester.tap(find.text('Yeni belge'));
      await tester.pumpAndSettle();

      // Unchanged: closes without asking.
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_field('Belge no'), findsNothing);

      await tester.tap(find.text('Yeni belge'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Belge no'), 'X');
      await tester.pump();
      expect(ctx.dirtyChanges.last, isTrue);

      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.discardChangesTitle), findsOneWidget);
      // Keep editing.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Vazgeç'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_field('Belge no'), findsOneWidget);

      // Discard.
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.discardChangesConfirm));
      await tester.pumpAndSettle();
      expect(_field('Belge no'), findsNothing);
      expect(ctx.dirtyChanges.last, isFalse);
    });

    testWidgets('delete asks once and removes the document', (tester) async {
      final repo = MockCariBelgeRepository();
      await _pump(tester, id: '1', repository: repo);
      await _openBelgeler(tester);
      await tester.tap(find.byTooltip('Sil').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sil'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Silindi'), findsOneWidget);
      expect((await repo.list(1)).dataOrNull!.total, 3);
    });
  });
}
