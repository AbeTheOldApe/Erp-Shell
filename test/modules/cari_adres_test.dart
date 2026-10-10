import 'dart:async';

import 'package:dio/dio.dart';
import 'package:erp_shell/core/auth/auth_models.dart';
import 'package:erp_shell/core/auth/http_auth_repository.dart';
import 'package:erp_shell/core/auth/session_controller.dart';
import 'package:erp_shell/core/config/app_config.dart';
import 'package:erp_shell/core/l10n/generated/app_localizations.dart';
import 'package:erp_shell/core/l10n/generated/app_localizations_tr.dart';
import 'package:erp_shell/core/network/api_client.dart';
import 'package:erp_shell/core/network/api_result.dart';
import 'package:erp_shell/core/storage/key_value_store.dart';
import 'package:erp_shell/core/theme/app_theme.dart';
import 'package:erp_shell/data/mock/mock_backend.dart';
import 'package:erp_shell/modules/cari/cari_adres_messages.dart';
import 'package:erp_shell/modules/cari/cari_module.dart';
import 'package:erp_shell/modules/cari/data/cari_adres_models.dart';
import 'package:erp_shell/modules/cari/data/cari_adres_repository.dart';
import 'package:erp_shell/modules/cari/data/cari_repository.dart';
import 'package:erp_shell/modules/cari/data/http_cari_adres_repository.dart';
import 'package:erp_shell/modules/cari/data/mock_cari_adres_repository.dart';
import 'package:erp_shell/modules/cari/data/mock_cari_repository.dart';
import 'package:erp_shell/core/auth/permissions.dart';
import 'package:erp_shell/modules/module_def.dart';
import 'package:erp_shell/modules/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/shell_harness.dart';

final _l10n = AppLocalizationsTr();

class _Context implements ModuleContext {
  _Context(this.permissions, {this.adresler, this.query = const {}});

  @override
  final ModulePermissions permissions;
  final ModulePermissions? adresler;
  @override
  final Map<String, String> query;
  final dirtyChanges = <bool>[];

  @override
  ModulePermissions subPermissions(String name) => adresler ?? permissions;
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

/// Counts how often the address types are fetched.
class _CountingRepository extends MockCariAdresRepository {
  int tipCalls = 0;

  @override
  Future<ApiResult<List<AdresTipi>>> tipler() {
    tipCalls++;
    return super.tipler();
  }
}

Future<_Context> _pump(
  WidgetTester tester, {
  required String id,
  IntegrationType type = IntegrationType.yok,
  ModulePermissions adresler = _all,
  CariAdresRepository? repository,
  Size size = const Size(500, 2600),
}) async {
  setWindowSize(tester, size);
  final ctx = _Context(_all, adresler: adresler, query: {'id': id});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(useMock: true, apiBaseUrl: '/api'),
        ),
        localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        cariRepositoryProvider.overrideWithValue(MockCariRepository()),
        cariAdresRepositoryProvider.overrideWithValue(
          repository ?? MockCariAdresRepository(),
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

Future<void> _openAdresler(WidgetTester tester) async {
  await tester.tap(find.text('Adresler'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _pickTipi(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('adres-tipi')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Kaydet').last);
  await tester.pumpAndSettle();
}

CariAdres _adres({
  int? tipi = 1,
  String il = '',
  String ilce = '',
  String mahalle = '',
  String cadde = '',
  String disKapi = '',
  String icKapi = '',
  String adres = '',
  String postaKodu = '',
}) => CariAdres(
  cariId: 1,
  adresTipiId: tipi,
  il: il,
  ilce: ilce,
  mahalle: mahalle,
  cadde: cadde,
  disKapi: disKapi,
  icKapi: icKapi,
  adres: adres,
  postaKodu: postaKodu,
);

(HttpCariAdresRepository, FakeAdapter) _http(
  FakeReply Function(RequestOptions) handler,
) {
  final adapter = FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
    ..httpClientAdapter = adapter;
  return (HttpCariAdresRepository(ApiClient(dio)), adapter);
}

void main() {
  group('tenant integration in the session', () {
    Future<IntegrationType> loginWith(Object? integration) async {
      final adapter = FakeAdapter((o) {
        if (o.path == '/auth/login') return tokenReply('t1');
        return FakeReply.ok(meData(integration: integration));
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;
      final session = await HttpAuthRepository(
        ApiClient(dio),
      ).login('esin', 'x');
      return session.user.integration;
    }

    test('/me Tenant.EntegrasyonTuru is read', () async {
      expect(await loginWith('Netsis'), IntegrationType.netsis);
      expect(await loginWith('Yok'), IntegrationType.yok);
    });

    test('unknown, empty or missing falls back to Yok', () async {
      expect(await loginWith('Logo'), IntegrationType.yok);
      expect(await loginWith(''), IntegrationType.yok);
      expect(await loginWith(null), IntegrationType.yok);
    });

    test('mock users: yonetici is Netsis, satis and depo are not', () {
      final backend = MockBackend();
      IntegrationType of(String username) => AuthSession.fromLoginResponse(
        backend.login(username),
        username: username,
      ).user.integration;
      expect(of('yonetici'), IntegrationType.netsis);
      expect(of('satis'), IntegrationType.yok);
      expect(of('depo'), IntegrationType.yok);
    });

    test('the stored mock session keeps the integration', () {
      final session = AuthSession.fromLoginResponse(
        MockBackend().login('yonetici'),
        username: 'yonetici',
      );
      final back = AuthSession.fromJson(session.toJson());
      expect(back.user.integration, IntegrationType.netsis);
    });
  });

  group('sub-permission of the Adresler tab', () {
    final sub = moduleRegistry['cari']!.subApi['adresler']!;

    test('is granted apart from CariMain', () {
      const onlyMain = ApiGrants(
        pages: {'CariMain'},
        buttons: {
          'CariMain': {'KAYDET', 'SIL'},
        },
      );
      expect(sub.resolve(onlyMain), ModulePermissions.none);
      expect(moduleRegistry['cari']!.api!.resolve(onlyMain).canDelete, isTrue);
    });

    test('canView from the page, add / edit / delete from the buttons', () {
      const grants = ApiGrants(
        pages: {'CariAdresler'},
        buttons: {
          'CariAdresler': {'KAYDET'},
        },
      );
      expect(
        sub.resolve(grants),
        const ModulePermissions(canView: true, canAdd: true, canEdit: true),
      );
      const withDelete = ApiGrants(
        pages: {'CariAdresler'},
        buttons: {
          'CariAdresler': {'SIL'},
        },
      );
      expect(
        sub.resolve(withDelete),
        const ModulePermissions(canView: true, canDelete: true),
      );
    });
  });

  group('field sets and validation', () {
    test('Yok and Netsis have their own fields', () {
      expect(adresFieldsFor(IntegrationType.yok), [
        AdresField.il,
        AdresField.ilce,
        AdresField.mahalle,
        AdresField.cadde,
        AdresField.disKapi,
        AdresField.icKapi,
      ]);
      expect(adresFieldsFor(IntegrationType.netsis), [
        AdresField.il,
        AdresField.ilce,
        AdresField.adres,
        AdresField.postaKodu,
      ]);
    });

    test('Netsis: Adres is required', () {
      final issues = validateAdres(_adres(il: 'Izmir'), IntegrationType.netsis);
      expect(issues, {AdresField.adres: AdresIssue.required});
    });

    test('Netsis: the postal code is exactly 5 digits when given', () {
      Map<AdresField, AdresIssue> check(String code) => validateAdres(
        _adres(adres: 'x', postaKodu: code),
        IntegrationType.netsis,
      );
      expect(check(''), isEmpty);
      expect(check('35100'), isEmpty);
      expect(check('3510'), {AdresField.postaKodu: AdresIssue.postaKodu});
      expect(check('35a00'), {AdresField.postaKodu: AdresIssue.postaKodu});
      expect(check('351000'), {AdresField.postaKodu: AdresIssue.postaKodu});
    });

    test('at least one field of the set must be filled', () {
      expect(validateAdres(_adres(), IntegrationType.yok), {
        AdresField.form: AdresIssue.atLeastOne,
      });
      // Blanks do not count; neither do fields of the other set.
      expect(
        validateAdres(
          _adres(il: '  ', adres: 'sadece netsis alani'),
          IntegrationType.yok,
        ).keys,
        [AdresField.form],
      );
      expect(validateAdres(_adres(disKapi: '4'), IntegrationType.yok), isEmpty);
    });

    test('the address type is required; lengths are limited', () {
      final issues = validateAdres(
        _adres(tipi: null, il: 'x' * 26, mahalle: 'y' * 51),
        IntegrationType.yok,
      );
      expect(issues, {
        AdresField.adresTipi: AdresIssue.required,
        AdresField.il: AdresIssue.tooLong,
        AdresField.mahalle: AdresIssue.tooLong,
      });
      expect(
        validateAdres(
          _adres(adres: 'a' * 256),
          IntegrationType.netsis,
        )[AdresField.adres],
        AdresIssue.tooLong,
      );
    });

    test('forTenant keeps only the fields of the set, trimmed', () {
      final kept = _adres(
        il: ' Izmir ',
        mahalle: 'Mah',
        adres: 'Cad 1',
        postaKodu: '35100',
      ).forTenant(IntegrationType.netsis);
      expect(kept.il, 'Izmir');
      expect(kept.adres, 'Cad 1');
      expect(kept.postaKodu, '35100');
      expect(kept.mahalle, '');
    });
  });

  group('MessageCode -> view', () {
    ApiFailure<Object?> rule(int code, [String message = 'sunucu']) =>
        ApiFailure(httpStatus: 200, messageCode: code, message: message);

    test('1002 / 1003 point at the fields the client can tell', () {
      final view = mapAdresFailure(
        _l10n,
        rule(1003),
        sent: _adres(adres: 'x', postaKodu: '12'),
        type: IntegrationType.netsis,
      );
      expect(view.fieldErrors, {
        AdresField.postaKodu: _l10n.adresPostaKoduInvalid,
      });
      final empty = mapAdresFailure(_l10n, rule(1002), sent: _adres());
      expect(empty.fieldErrors, {AdresField.form: _l10n.adresAtLeastOne});
    });

    test('1002 / 1003 the client cannot explain show the server text', () {
      final view = mapAdresFailure(
        _l10n,
        rule(1003, 'Gecersiz adres tipi.'),
        sent: _adres(il: 'Izmir'),
      );
      expect(view.fieldErrors, {AdresField.form: 'Gecersiz adres tipi.'});
    });

    test('1004 and 1005 inform and refresh the list', () {
      final notFound = mapAdresFailure(_l10n, rule(1004));
      expect(notFound.message, _l10n.recordNotFound);
      expect(notFound.isInfo && notFound.refreshList, isTrue);
      final gone = mapAdresFailure(_l10n, rule(1005));
      expect(gone.message, _l10n.cariAlreadyDeleted);
      expect(gone.refreshList, isTrue);
    });

    test('1203 is an information message; unknown codes use the server', () {
      final linked = mapAdresFailure(_l10n, rule(1203));
      expect(linked.message, _l10n.apiMessage1203);
      expect(linked.isInfo, isTrue);
      expect(mapAdresFailure(_l10n, rule(1999)).message, 'sunucu');
    });
  });

  group('HTTP repository', () {
    test('list: maps the PascalCase items and NetsisBagliMi', () async {
      final (repo, adapter) = _http(
        (_) => FakeReply.ok({
          'Items': [
            {
              'CariAdresId': 5828,
              'CariId': 5574,
              'AdresTipiId': 1,
              'AdresTipi': 'Fatura',
              'Il': 'Izmir',
              'Ilce': 'Bornova',
              'MahalleKoyMezraMevkii': 'Test Mah.',
              'CaddeSokakBucakMahalle': null,
              'DisKapi': null,
              'IcKapi': null,
              'Adres': null,
              'PostaKodu': null,
            },
          ],
          'NetsisBagliMi': true,
        }),
      );
      final list = (await repo.list(5574)).dataOrNull!;
      expect(adapter.requests.single.path, '/tml/cari/5574/adresler');
      expect(list.netsisBagli, isTrue);
      final adres = list.items.single;
      expect(adres.id, 5828);
      expect(adres.adresTipi, 'Fatura');
      expect(adres.mahalle, 'Test Mah.');
      expect(adres.cadde, '');
    });

    test('save with the Yok set sends only its fields', () async {
      final (repo, adapter) = _http((_) => FakeReply.ok({'CariAdresId': 7}));
      final id = (await repo.save(
        _adres(il: ' Izmir ', mahalle: 'Mah', adres: 'gonderilmez'),
        IntegrationType.yok,
      )).dataOrNull;
      expect(id, 7);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/tml/cari-adres');
      expect(request.body, {
        'CariId': 1,
        'AdresTipiId': 1,
        'Il': 'Izmir',
        'Ilce': '',
        'MahalleKoyMezraMevkii': 'Mah',
        'CaddeSokakBucakMahalle': '',
        'DisKapi': '',
        'IcKapi': '',
      });
    });

    test('save with the Netsis set; an update carries its id', () async {
      final (repo, adapter) = _http((_) => FakeReply.ok({'CariAdresId': 9}));
      await repo.save(
        const CariAdres(
          id: 9,
          cariId: 1,
          adresTipiId: 2,
          mahalle: 'gonderilmez',
          adres: 'Cad 1',
          postaKodu: '35100',
        ),
        IntegrationType.netsis,
      );
      expect(adapter.requests.single.body, {
        'CariAdresId': 9,
        'CariId': 1,
        'AdresTipiId': 2,
        'Il': '',
        'Ilce': '',
        'Adres': 'Cad 1',
        'PostaKodu': '35100',
      });
    });

    test('delete and address types', () async {
      final (repo, adapter) = _http((o) {
        if (o.path == '/tml/adres-tipleri') {
          return FakeReply.ok({
            'Items': [
              {'AdresTipiId': 1, 'AdresTipi': 'Fatura'},
              {'AdresTipiId': 2, 'AdresTipi': 'Sevk'},
            ],
          });
        }
        return FakeReply.ok({'CariAdresId': 3});
      });
      expect((await repo.delete(3)).isSuccess, isTrue);
      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.path, '/tml/cari-adres/3');
      final tipler = (await repo.tipler()).dataOrNull!;
      expect(tipler.map((t) => t.ad), ['Fatura', 'Sevk']);
    });
  });

  group('mock repository', () {
    test('add -> list -> edit -> delete', () async {
      final repo = MockCariAdresRepository();
      final before = (await repo.list(1)).dataOrNull!.items.length;

      final id = (await repo.save(
        _adres(il: 'Konya', mahalle: 'Merkez'),
        IntegrationType.yok,
      )).dataOrNull!;
      var items = (await repo.list(1)).dataOrNull!.items;
      expect(items.length, before + 1);
      expect(items.any((a) => a.id == id), isTrue);

      final edited = CariAdres(
        id: id,
        cariId: 1,
        adresTipiId: 2,
        il: 'Ankara',
        mahalle: 'Merkez',
      );
      expect((await repo.save(edited, IntegrationType.yok)).isSuccess, isTrue);
      items = (await repo.list(1)).dataOrNull!.items;
      final saved = items.firstWhere((a) => a.id == id);
      expect(saved.il, 'Ankara');
      expect(saved.adresTipi, isNotEmpty);

      expect((await repo.delete(id)).isSuccess, isTrue);
      expect(
        (await repo.list(1)).dataOrNull!.items.any((a) => a.id == id),
        isFalse,
      );
      expect((await repo.delete(id)).failureOrNull!.messageCode, 1004);
    });

    test('an update keeps the fields outside the tenant set', () async {
      final repo = MockCariAdresRepository();
      final first = (await repo.list(1)).dataOrNull!.items.last;
      expect(first.adres, isNotEmpty);
      await repo.save(
        CariAdres(
          id: first.id,
          cariId: 1,
          adresTipiId: first.adresTipiId,
          il: 'Yeni il',
        ),
        IntegrationType.yok,
      );
      final after = (await repo.list(1)).dataOrNull!.items.last;
      expect(after.il, 'Yeni il');
      expect(after.adres, first.adres);
    });

    test('server rules and the Netsis-linked cari', () async {
      final repo = MockCariAdresRepository();
      expect(
        (await repo.save(
          _adres(),
          IntegrationType.yok,
        )).failureOrNull!.messageCode,
        1002,
      );
      expect(
        (await repo.save(
          _adres(tipi: 99, il: 'x'),
          IntegrationType.yok,
        )).failureOrNull!.messageCode,
        1003,
      );
      expect(
        (await repo.save(
          _adres(adres: 'x', postaKodu: '12'),
          IntegrationType.netsis,
        )).failureOrNull!.messageCode,
        1003,
      );
      final linked = (await repo.list(9)).dataOrNull!;
      expect(linked.netsisBagli, isTrue);
      expect(linked.items, isNotEmpty);
      expect(
        (await repo.delete(linked.items.first.id!)).failureOrNull!.messageCode,
        1203,
      );
      expect((await repo.list(1)).dataOrNull!.netsisBagli, isFalse);
    });
  });

  group('address types per session', () {
    test('fetched once, dropped when the user changes', () async {
      final repo = _CountingRepository();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(useMock: true, apiBaseUrl: '/api'),
          ),
          localStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          sessionStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          cariAdresRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(adresTipleriProvider, (_, _) {});
      addTearDown(listener.close);

      final first = await container.read(adresTipleriProvider.future);
      await container.read(adresTipleriProvider.future);
      expect(first, isNotEmpty);
      expect(repo.tipCalls, 1);

      // Signing in as someone else starts a new session.
      await container.read(sessionProvider.notifier).login('satis', '1234');
      await container.read(adresTipleriProvider.future);
      expect(repo.tipCalls, 2);
    });

    testWidgets('opening the form twice asks the API once', (tester) async {
      final repo = _CountingRepository();
      await _pump(tester, id: '1', repository: repo);
      await _openAdresler(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Yeni adres'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Kapat'));
        await tester.pumpAndSettle();
      }
      expect(repo.tipCalls, 1);
    });
  });

  group('screen', () {
    testWidgets('Yok tenant: the Yok fields', (tester) async {
      await _pump(tester, id: '1');
      await _openAdresler(tester);
      await tester.tap(find.text('Yeni adres'));
      await tester.pumpAndSettle();
      for (final label in [
        'Adres tipi *',
        'İl',
        'İlçe',
        'Mahalle / Köy / Mezra / Mevkii',
        'Cadde / Sokak / Bucak / Mahalle',
        'Dış kapı',
        'İç kapı',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Adres *'), findsNothing);
      expect(find.text('Posta kodu'), findsNothing);
    });

    testWidgets('Netsis tenant: the Netsis fields', (tester) async {
      await _pump(tester, id: '1', type: IntegrationType.netsis);
      await _openAdresler(tester);
      await tester.tap(find.text('Yeni adres'));
      await tester.pumpAndSettle();
      for (final label in [
        'Adres tipi *',
        'İl',
        'İlçe',
        'Adres *',
        'Posta kodu',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Dış kapı'), findsNothing);
      expect(find.text('Mahalle / Köy / Mezra / Mevkii'), findsNothing);
    });

    testWidgets('Netsis: required Adres, 5-digit postal code', (tester) async {
      final repo = MockCariAdresRepository();
      await _pump(
        tester,
        id: '1',
        type: IntegrationType.netsis,
        repository: repo,
      );
      await _openAdresler(tester);
      final before = (await repo.list(1)).dataOrNull!.items.length;
      await tester.tap(find.text('Yeni adres'));
      await tester.pumpAndSettle();

      await _save(tester);
      // The type and the Adres field.
      expect(find.text(_l10n.validationRequired), findsNWidgets(2));

      await _pickTipi(tester, 'Fatura adresi');
      await tester.enterText(_field('Adres *'), 'Cad. 1');
      await tester.enterText(_field('Posta kodu'), '123');
      await _save(tester);
      expect(find.text(_l10n.adresPostaKoduInvalid), findsOneWidget);

      await tester.enterText(_field('Posta kodu'), '35100');
      await _save(tester);
      expect(find.text('Kaydedildi'), findsOneWidget);
      expect((await repo.list(1)).dataOrNull!.items.length, before + 1);
    });

    testWidgets('Yok: at least one field must be filled', (tester) async {
      await _pump(tester, id: '1');
      await _openAdresler(tester);
      await tester.tap(find.text('Yeni adres'));
      await tester.pumpAndSettle();
      await _pickTipi(tester, 'Fatura adresi');
      await _save(tester);
      expect(find.text(_l10n.adresAtLeastOne), findsOneWidget);

      await tester.enterText(_field('İl'), 'Konya');
      await _save(tester);
      expect(find.text(_l10n.adresAtLeastOne), findsNothing);
      expect(find.text('Kaydedildi'), findsOneWidget);
    });

    testWidgets('add, edit and delete from the screen', (tester) async {
      final repo = MockCariAdresRepository();
      await _pump(tester, id: '2', repository: repo);
      await _openAdresler(tester);
      // Cari 2 has one address (Çankaya / Ankara).
      expect(find.textContaining('Ankara'), findsOneWidget);

      await tester.tap(find.text('Yeni adres'));
      await tester.pumpAndSettle();
      await _pickTipi(tester, 'Sevkiyat adresi');
      await tester.enterText(_field('İl'), 'Konya');
      await tester.enterText(_field('Dış kapı'), '12');
      await _save(tester);
      expect(find.textContaining('Konya'), findsOneWidget);
      expect(find.text('No: 12, Konya'), findsOneWidget);

      // Edit the new one (the second card).
      await tester.tap(find.byTooltip('Adresi düzenle').last);
      await tester.pumpAndSettle();
      await tester.enterText(_field('İl'), 'Sivas');
      await _save(tester);
      expect(find.textContaining('Konya'), findsNothing);
      expect(find.textContaining('Sivas'), findsOneWidget);

      // Delete it (one confirmation).
      await tester.tap(find.byTooltip('Sil').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sil'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Silindi'), findsOneWidget);
      expect(find.textContaining('Sivas'), findsNothing);
      expect((await repo.list(2)).dataOrNull!.items.length, 1);
    });

    testWidgets('a Cari linked to Netsis: read-only with a band', (
      tester,
    ) async {
      await _pump(tester, id: '9');
      await _openAdresler(tester);
      expect(find.text(_l10n.cariNetsisReadonly), findsOneWidget);
      expect(find.textContaining('Bursa'), findsOneWidget);
      expect(find.text('Yeni adres'), findsNothing);
      expect(find.byTooltip('Adresi düzenle'), findsNothing);
      expect(find.byTooltip('Sil'), findsNothing);
    });

    testWidgets('buttons follow the sub-permissions', (tester) async {
      Future<void> check(
        ModulePermissions p, {
        required bool add,
        required bool edit,
        required bool delete,
      }) async {
        await _pump(tester, id: '1', adresler: p);
        await _openAdresler(tester);
        expect(find.text('Yeni adres'), add ? findsOneWidget : findsNothing);
        expect(
          find.byTooltip('Adresi düzenle'),
          edit ? findsWidgets : findsNothing,
        );
        expect(find.byTooltip('Sil'), delete ? findsWidgets : findsNothing);
        // The addresses themselves are always listed.
        expect(find.textContaining('Kadıköy'), findsOneWidget);
      }

      await check(
        const ModulePermissions(canView: true),
        add: false,
        edit: false,
        delete: false,
      );
      await check(
        const ModulePermissions(canView: true, canAdd: true),
        add: true,
        edit: false,
        delete: false,
      );
      await check(
        const ModulePermissions(canView: true, canEdit: true),
        add: false,
        edit: true,
        delete: false,
      );
      await check(
        const ModulePermissions(canView: true, canDelete: true),
        add: false,
        edit: false,
        delete: true,
      );
    });

    testWidgets('the tab is independent of the Cari permissions', (
      tester,
    ) async {
      // Without CariAdresler the tab is gone, though the Cari opens.
      await _pump(tester, id: '1', adresler: ModulePermissions.none);
      expect(find.text('Cari ünvanı *'), findsOneWidget);
      expect(find.text('Adresler'), findsNothing);
      expect(find.text('Genel'), findsNothing);
    });

    testWidgets('a new Cari: the tab is disabled and explained', (
      tester,
    ) async {
      await _pump(tester, id: 'yeni');
      expect(find.text(_l10n.adresSaveFirst), findsOneWidget);
      final button = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(button.segments.last.enabled, isFalse);
      await tester.tap(find.text('Adresler'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Yeni adres'), findsNothing);
      expect(find.text('Cari ünvanı *'), findsOneWidget);
    });

    testWidgets('a saved Cari enables the tab', (tester) async {
      await _pump(tester, id: 'yeni');
      await tester.enterText(_field('Cari ünvanı *'), 'Yeni Firma A.Ş.');
      await tester.tap(find.byTooltip('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.adresSaveFirst), findsNothing);
      final button = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(button.segments.last.enabled, isTrue);
    });

    testWidgets('a changed form asks before closing', (tester) async {
      final ctx = await _pump(tester, id: '1', size: const Size(1100, 900));
      await _openAdresler(tester);
      await tester.tap(find.text('Yeni adres'));
      await tester.pumpAndSettle();

      // Unchanged: closes without asking.
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Adres tipi *'), findsNothing);

      await tester.tap(find.text('Yeni adres'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('İl'), 'Konya');
      await tester.pump();
      expect(ctx.dirtyChanges.last, isTrue);

      await tester.tap(find.text('Vazgeç'));
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
      expect(_field('İl'), findsOneWidget);
      expect(ctx.dirtyChanges.last, isTrue);

      // Discard.
      await tester.tap(find.text('Vazgeç').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.discardChangesConfirm));
      await tester.pumpAndSettle();
      expect(_field('İl'), findsNothing);
      expect(ctx.dirtyChanges.last, isFalse);
    });
  });
}
