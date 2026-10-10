import '../../../core/auth/auth_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/utils/decimal_units.dart';
import 'cari_belge_models.dart';
import 'cari_belge_repository.dart';

/// The API's field names (PascalCase) and its decimal numbers live here and
/// nowhere else; the app works with whole units.
class HttpCariBelgeRepository implements CariBelgeRepository {
  const HttpCariBelgeRepository(this._client);

  final ApiClient _client;

  @override
  Future<ApiResult<BelgeListe>> list(
    int cariId, {
    int page = 1,
    int pageSize = 25,
  }) => _client.send<BelgeListe>(
    'GET',
    '/fi/cari/$cariId/belgeler',
    query: {'Page': page < 1 ? 1 : page, 'PageSize': pageSize.clamp(1, 200)},
    parse: (data) {
      final map = data! as Map<String, dynamic>;
      return BelgeListe(
        items: [
          for (final item in map['Items'] as List<dynamic>? ?? [])
            _ozet(item as Map<String, dynamic>),
        ],
        total: map['TotalCount'] as int? ?? 0,
      );
    },
  );

  @override
  Future<ApiResult<CariBelge>> get(int id) => _client.send<CariBelge>(
    'GET',
    '/fi/cari-belge/$id',
    parse: (data) => _belge(data! as Map<String, dynamic>),
  );

  @override
  Future<ApiResult<int>> save(CariBelge belge, IntegrationType type) {
    final netsis = type == IntegrationType.netsis;
    return _client.send<int>(
      'POST',
      '/fi/cari-belge',
      body: {
        if (belge.id != null && belge.id! > 0) 'CariBelgeId': belge.id,
        'CariId': belge.cariId,
        'CariBelgeTipiId': belge.tipiId,
        'CariBelgeNo': belge.no.trim(),
        'CariBelgeTarihi': isoDate(belge.tarih),
        'DovizBirimiId': belge.dovizId,
        if (belge.vadeId != null) 'OdemeVadeId': belge.vadeId,
        // Always the whole list: lines missing from it are deleted.
        'Kalemler': [
          for (final k in belge.kalemler)
            {
              if (k.id != null && k.id! > 0) 'CariBelgeKalemId': k.id,
              // Only the Netsis set writes the stock card; an existing one
              // must be sent back or it is cleared.
              if (netsis && k.stokKartiId != null) 'StokKartiId': k.stokKartiId,
              'Miktar': unitsToJson(
                k.miktar,
                decimals: CariBelgeLimits.miktarDecimals,
              ),
              'BirimId': k.birimId,
              'Tutar': unitsToJson(
                k.tutar ?? 0,
                decimals: CariBelgeLimits.tutarDecimals,
              ),
            },
        ],
      },
      parse: (data) => (data! as Map<String, dynamic>)['CariBelgeId'] as int,
    );
  }

  @override
  Future<ApiResult<void>> delete(int id) =>
      _client.send<void>('DELETE', '/fi/cari-belge/$id', parse: (_) {});

  @override
  Future<ApiResult<BelgeSecenekleri>> secenekler() =>
      _client.send<BelgeSecenekleri>(
        'GET',
        '/fi/cari-belge-secenekleri',
        parse: (data) {
          final map = data! as Map<String, dynamic>;
          List<Map<String, dynamic>> items(String key) => [
            for (final item in map[key] as List<dynamic>? ?? [])
              item as Map<String, dynamic>,
          ];
          return BelgeSecenekleri(
            tipler: [
              for (final m in items('BelgeTipleri'))
                BelgeTipi(
                  m['CariBelgeTipiId'] as int,
                  _str(m, 'CariBelgeTipi'),
                  m['Sign'] as int? ?? 0,
                ),
            ],
            dovizler: [
              for (final m in items('DovizBirimleri'))
                BelgeDoviz(
                  m['DovizBirimiId'] as int,
                  _str(m, 'DovizBirimi'),
                  _str(m, 'DovizSimgesi'),
                ),
            ],
            birimler: [
              for (final m in items('Birimler'))
                BelgeBirim(m['BirimId'] as int, _str(m, 'Birim')),
            ],
            vadeler: [
              for (final m in items('Vadeler'))
                BelgeVade(
                  m['OdemeVadeId'] as int,
                  _str(m, 'OdemeVade'),
                  m['OdemeVadeGunSayisi'] as int? ?? 0,
                ),
            ],
          );
        },
      );

  static String _str(Map<String, dynamic> m, String key) {
    final value = m[key];
    return value == null ? '' : '$value';
  }

  static DateTime _date(Map<String, dynamic> m) =>
      parseIsoDate(m['CariBelgeTarihi']) ?? DateTime(1900);

  static BelgeOzet _ozet(Map<String, dynamic> m) => BelgeOzet(
    id: m['CariBelgeId'] as int,
    tipi: _str(m, 'CariBelgeTipi'),
    no: _str(m, 'CariBelgeNo'),
    tarih: _date(m),
    dovizKodu: _str(m, 'DovizBirimi'),
    kalemSayisi: m['KalemSayisi'] as int? ?? 0,
    toplamKurus:
        unitsFromJson(
          m['ToplamTutar'],
          decimals: CariBelgeLimits.tutarDecimals,
        ) ??
        0,
  );

  static CariBelge _belge(Map<String, dynamic> m) => CariBelge(
    id: m['CariBelgeId'] as int,
    cariId: m['CariId'] as int,
    tipiId: m['CariBelgeTipiId'] as int?,
    tipi: _str(m, 'CariBelgeTipi'),
    no: _str(m, 'CariBelgeNo'),
    tarih: _date(m),
    dovizId: m['DovizBirimiId'] as int?,
    dovizKodu: _str(m, 'DovizBirimi'),
    vadeId: m['OdemeVadeId'] as int?,
    kalemler: [
      for (final item in m['Kalemler'] as List<dynamic>? ?? [])
        _kalem(item as Map<String, dynamic>),
    ],
  );

  static BelgeKalem _kalem(Map<String, dynamic> m) => BelgeKalem(
    id: m['CariBelgeKalemId'] as int?,
    stokKartiId: m['StokKartiId'] as int?,
    miktar:
        unitsFromJson(m['Miktar'], decimals: CariBelgeLimits.miktarDecimals) ??
        10000,
    birimId: m['BirimId'] as int?,
    birim: _str(m, 'Birim'),
    tutar: unitsFromJson(m['Tutar'], decimals: CariBelgeLimits.tutarDecimals),
  );
}
