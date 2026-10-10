import '../../../core/auth/auth_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import 'cari_adres_models.dart';
import 'cari_adres_repository.dart';

/// The API's field names (PascalCase) live here and nowhere else.
class HttpCariAdresRepository implements CariAdresRepository {
  const HttpCariAdresRepository(this._client);

  final ApiClient _client;

  @override
  Future<ApiResult<CariAdresList>> list(int cariId) =>
      _client.send<CariAdresList>(
        'GET',
        '/tml/cari/$cariId/adresler',
        parse: (data) {
          final map = data! as Map<String, dynamic>;
          return CariAdresList(
            items: [
              for (final item in map['Items'] as List<dynamic>? ?? [])
                _adres(item as Map<String, dynamic>),
            ],
            netsisBagli: map['NetsisBagliMi'] == true,
          );
        },
      );

  @override
  Future<ApiResult<int>> save(CariAdres adres, IntegrationType type) {
    final fields = adresFieldsFor(type);
    final value = adres.forTenant(type);
    return _client.send<int>(
      'POST',
      '/tml/cari-adres',
      body: {
        if (adres.id != null && adres.id! > 0) 'CariAdresId': adres.id,
        'CariId': adres.cariId,
        'AdresTipiId': adres.adresTipiId,
        // Fields outside the tenant's set are not sent.
        for (final field in fields) _apiName(field): value.valueOf(field),
      },
      parse: (data) => (data! as Map<String, dynamic>)['CariAdresId'] as int,
    );
  }

  @override
  Future<ApiResult<void>> delete(int id) =>
      _client.send<void>('DELETE', '/tml/cari-adres/$id', parse: (_) {});

  @override
  Future<ApiResult<List<AdresTipi>>> tipler() => _client.send<List<AdresTipi>>(
    'GET',
    '/tml/adres-tipleri',
    parse: (data) {
      final map = data! as Map<String, dynamic>;
      return [
        for (final item in map['Items'] as List<dynamic>? ?? [])
          AdresTipi(
            (item as Map<String, dynamic>)['AdresTipiId'] as int,
            _str(item, 'AdresTipi'),
          ),
      ];
    },
  );

  static String _apiName(AdresField field) => switch (field) {
    AdresField.il => 'Il',
    AdresField.ilce => 'Ilce',
    AdresField.mahalle => 'MahalleKoyMezraMevkii',
    AdresField.cadde => 'CaddeSokakBucakMahalle',
    AdresField.disKapi => 'DisKapi',
    AdresField.icKapi => 'IcKapi',
    AdresField.adres => 'Adres',
    AdresField.postaKodu => 'PostaKodu',
    AdresField.adresTipi => 'AdresTipiId',
    AdresField.form => '',
  };

  static String _str(Map<String, dynamic> m, String key) {
    final value = m[key];
    return value == null ? '' : '$value';
  }

  static CariAdres _adres(Map<String, dynamic> m) => CariAdres(
    id: m['CariAdresId'] as int,
    cariId: m['CariId'] as int,
    adresTipiId: m['AdresTipiId'] as int?,
    adresTipi: _str(m, 'AdresTipi'),
    il: _str(m, 'Il'),
    ilce: _str(m, 'Ilce'),
    mahalle: _str(m, 'MahalleKoyMezraMevkii'),
    cadde: _str(m, 'CaddeSokakBucakMahalle'),
    disKapi: _str(m, 'DisKapi'),
    icKapi: _str(m, 'IcKapi'),
    adres: _str(m, 'Adres'),
    postaKodu: _str(m, 'PostaKodu'),
  );
}
