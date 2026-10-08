import 'package:dio/dio.dart';
import 'package:erp_shell/core/network/api_client.dart';
import 'package:erp_shell/modules/cari/data/cari_models.dart';
import 'package:erp_shell/modules/cari/data/http_cari_repository.dart';
import 'package:erp_shell/shared/app_data_grid/grid_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';

const _row = {
  'CariId': 5563,
  'CariKodu': 'C1',
  'Cari': 'Firma',
  'CariUnvani': 'Firma A.Ş.',
  'CariKisaUnvani': 'Firma',
  'TelefonNo': '0212',
  'EPostaAdresi': 'a@b.c',
  'VergiDairesi': '',
  'VergiNo': '123',
  'TcKimlikNo': '',
  'CarininMusteriRoluVarMi': true,
  'CarininUrunTedarikcisiRoluVarMi': false,
  'CarininHizmetTedarikcisiRoluVarMi': true,
  'Status': 'Valid',
  'NetsisBagliMi': true,
};

(HttpCariRepository, FakeAdapter) _repo(
  FakeReply Function(RequestOptions) handler,
) {
  final adapter = FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
    ..httpClientAdapter = adapter;
  return (HttpCariRepository(ApiClient(dio)), adapter);
}

void main() {
  test(
    'list: sends the translated query and maps the PascalCase rows',
    () async {
      final (repo, adapter) = _repo(
        (_) => FakeReply.ok({
          'Items': [
            _row,
            {..._row, 'CariId': 2, 'Status': 'Invalid', 'NetsisBagliMi': false},
          ],
          'TotalCount': 175,
          'Page': 2,
          'PageSize': 50,
        }),
      );
      final result = await repo.list(
        const GridQuery(
          page: 2,
          pageSize: 50,
          sort: [GridSort('unvan')],
          filters: [
            GridFilter('arama', FilterOp.contains, 'firma'),
            GridFilter('musteri', FilterOp.eq, true),
          ],
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/tml/cari');
      expect(request.query, {
        'Page': 2,
        'PageSize': 50,
        'Arama': 'firma',
        'CarininMusteriRoluVarMi': true,
      });
      final page = result.dataOrNull!;
      expect(page.total, 175);
      final first = page.items.first;
      expect(first.id, 5563);
      expect(first.unvan, 'Firma A.Ş.');
      expect(first.vergiTc, '123');
      expect(first.musteri && first.hizmetTedarikcisi, isTrue);
      expect(first.urunTedarikcisi, isFalse);
      expect(first.aktif, isTrue);
      expect(first.netsisBagli, isTrue);
      expect(page.items.last.aktif, isFalse);
    },
  );

  test('get: maps the form fields', () async {
    final (repo, adapter) = _repo(
      (_) => FakeReply.ok({
        ..._row,
        'WebAdresi': 'www.x.y',
        'FaksNo': '0216',
        'OtomatikCariEkstreYollansinMi': true,
      }),
    );
    final cari = (await repo.get(5563)).dataOrNull!;
    expect(adapter.requests.single.path, '/tml/cari/5563');
    expect(cari.webAdresi, 'www.x.y');
    expect(cari.faks, '0216');
    expect(cari.otomatikEkstre, isTrue);
    expect(cari.cari, 'Firma');
  });

  test('get: 1004 is a failure value', () async {
    final (repo, _) = _repo((_) => FakeReply.fail(200, 1004, 'Yok'));
    final failure = (await repo.get(1)).failureOrNull!;
    expect(failure.isBusinessRule, isTrue);
    expect(failure.messageCode, 1004);
  });

  test(
    'save: new has no CariId, update has; no read-only fields sent',
    () async {
      final (repo, adapter) = _repo((_) => FakeReply.ok({'CariId': 5564}));
      final created = await repo.save(
        const Cari(unvan: ' Yeni ', kod: 'K1', musteri: true),
      );
      expect(created.dataOrNull, 5564);
      final newBody = adapter.requests.last.body! as Map<String, dynamic>;
      expect(adapter.requests.last.method, 'POST');
      expect(newBody.containsKey('CariId'), isFalse);
      expect(newBody['CariUnvani'], 'Yeni');
      expect(newBody['CariKodu'], 'K1');
      expect(newBody['CarininMusteriRoluVarMi'], true);
      expect(newBody.containsKey('Status'), isFalse);
      expect(newBody.containsKey('NetsisBagliMi'), isFalse);

      await repo.save(const Cari(id: 7, unvan: 'Var'));
      final updateBody = adapter.requests.last.body! as Map<String, dynamic>;
      expect(updateBody['CariId'], 7);
    },
  );

  test('save: 1201 comes back as a rule failure', () async {
    final (repo, _) = _repo((_) => FakeReply.fail(200, 1201, 'Kod var'));
    final failure = (await repo.save(const Cari(unvan: 'x'))).failureOrNull!;
    expect(failure.messageCode, 1201);
  });

  test('delete: DELETE /tml/cari/{id}', () async {
    final (repo, adapter) = _repo((_) => FakeReply.ok(null));
    final result = await repo.delete(9);
    expect(result.isSuccess, isTrue);
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/tml/cari/9');
  });

  test('an HTTP 403 is a failure value too', () async {
    final (repo, _) = _repo((_) => FakeReply.fail(403, 2003, 'Yetki yok'));
    final failure = (await repo.delete(9)).failureOrNull!;
    expect(failure.isForbidden, isTrue);
  });
}
