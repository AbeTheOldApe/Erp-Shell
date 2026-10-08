import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../shared/app_data_grid/grid_query.dart';
import 'cari_models.dart';
import 'cari_repository.dart';

/// Translates a [GridQuery] to the query parameters of `GET /tml/cari`
/// (`docs/api-contract.md` §6.1). Filters the API does not know and any sort
/// are not sent.
Map<String, dynamic> cariQueryParameters(GridQuery query) {
  String? text(String field) {
    for (final f in query.filters) {
      if (f.field == field && f.op == FilterOp.contains) {
        final value = '${f.value ?? ''}'.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  bool flag(String field) => query.filters.any(
    (f) => f.field == field && f.op == FilterOp.eq && f.value == true,
  );

  final search = text(CariFilters.arama);
  return {
    'Page': query.page < 1 ? 1 : query.page,
    'PageSize': query.pageSize.clamp(1, 200),
    if (search != null)
      'Arama': search.length > 100 ? search.substring(0, 100) : search,
    // Only "has the role" is a filter; unticked sends nothing.
    if (flag(CariFilters.musteri)) 'CarininMusteriRoluVarMi': true,
    if (flag(CariFilters.urunTedarikcisi))
      'CarininUrunTedarikcisiRoluVarMi': true,
    if (flag(CariFilters.hizmetTedarikcisi))
      'CarininHizmetTedarikcisiRoluVarMi': true,
    if (flag(CariFilters.pasif)) 'PasifGoster': true,
  };
}

/// The API's field names (PascalCase) live here and nowhere else.
class HttpCariRepository implements CariRepository {
  const HttpCariRepository(this._client);

  final ApiClient _client;

  @override
  Future<ApiResult<GridPage<CariOzet>>> list(GridQuery query) =>
      _client.send<GridPage<CariOzet>>(
        'GET',
        '/tml/cari',
        query: cariQueryParameters(query),
        parse: (data) {
          final map = data! as Map<String, dynamic>;
          return GridPage(
            items: [
              for (final item in map['Items'] as List<dynamic>? ?? [])
                _ozet(item as Map<String, dynamic>),
            ],
            total: map['TotalCount'] as int? ?? 0,
          );
        },
      );

  @override
  Future<ApiResult<Cari>> get(int id) => _client.send<Cari>(
    'GET',
    '/tml/cari/$id',
    parse: (data) => _cari(data! as Map<String, dynamic>),
  );

  @override
  Future<ApiResult<int>> save(Cari cari) => _client.send<int>(
    'POST',
    '/tml/cari',
    body: {
      if (cari.id != null && cari.id! > 0) 'CariId': cari.id,
      'CariKodu': cari.kod.trim(),
      'Cari': cari.cari.trim(),
      'CariUnvani': cari.unvan.trim(),
      'CariKisaUnvani': cari.kisaUnvan.trim(),
      'WebAdresi': cari.webAdresi.trim(),
      'EPostaAdresi': cari.ePosta.trim(),
      'TelefonNo': cari.telefon.trim(),
      'FaksNo': cari.faks.trim(),
      'VergiDairesi': cari.vergiDairesi.trim(),
      'VergiNo': cari.vergiNo.trim(),
      'TcKimlikNo': cari.tcKimlikNo.trim(),
      'CarininMusteriRoluVarMi': cari.musteri,
      'CarininUrunTedarikcisiRoluVarMi': cari.urunTedarikcisi,
      'CarininHizmetTedarikcisiRoluVarMi': cari.hizmetTedarikcisi,
      'OtomatikCariEkstreYollansinMi': cari.otomatikEkstre,
    },
    parse: (data) => (data! as Map<String, dynamic>)['CariId'] as int,
  );

  @override
  Future<ApiResult<void>> delete(int id) =>
      _client.send<void>('DELETE', '/tml/cari/$id', parse: (_) {});

  static String _str(Map<String, dynamic> m, String key) {
    final value = m[key];
    return value == null ? '' : '$value';
  }

  static bool _bool(Map<String, dynamic> m, String key) => m[key] == true;

  static bool _aktif(Map<String, dynamic> m) => m['Status'] == 'Valid';

  static CariOzet _ozet(Map<String, dynamic> m) => CariOzet(
    id: m['CariId'] as int,
    kod: _str(m, 'CariKodu'),
    unvan: _str(m, 'CariUnvani'),
    kisaUnvan: _str(m, 'CariKisaUnvani'),
    telefon: _str(m, 'TelefonNo'),
    ePosta: _str(m, 'EPostaAdresi'),
    vergiNo: _str(m, 'VergiNo'),
    tcKimlikNo: _str(m, 'TcKimlikNo'),
    musteri: _bool(m, 'CarininMusteriRoluVarMi'),
    urunTedarikcisi: _bool(m, 'CarininUrunTedarikcisiRoluVarMi'),
    hizmetTedarikcisi: _bool(m, 'CarininHizmetTedarikcisiRoluVarMi'),
    aktif: _aktif(m),
    netsisBagli: _bool(m, 'NetsisBagliMi'),
  );

  static Cari _cari(Map<String, dynamic> m) => Cari(
    id: m['CariId'] as int,
    kod: _str(m, 'CariKodu'),
    cari: _str(m, 'Cari'),
    unvan: _str(m, 'CariUnvani'),
    kisaUnvan: _str(m, 'CariKisaUnvani'),
    webAdresi: _str(m, 'WebAdresi'),
    ePosta: _str(m, 'EPostaAdresi'),
    telefon: _str(m, 'TelefonNo'),
    faks: _str(m, 'FaksNo'),
    vergiDairesi: _str(m, 'VergiDairesi'),
    vergiNo: _str(m, 'VergiNo'),
    tcKimlikNo: _str(m, 'TcKimlikNo'),
    musteri: _bool(m, 'CarininMusteriRoluVarMi'),
    urunTedarikcisi: _bool(m, 'CarininUrunTedarikcisiRoluVarMi'),
    hizmetTedarikcisi: _bool(m, 'CarininHizmetTedarikcisiRoluVarMi'),
    otomatikEkstre: _bool(m, 'OtomatikCariEkstreYollansinMi'),
    aktif: _aktif(m),
    netsisBagli: _bool(m, 'NetsisBagliMi'),
  );
}
