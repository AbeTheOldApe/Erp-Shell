import '../../../core/auth/auth_models.dart';
import '../../../core/network/api_result.dart';
import 'cari_adres_models.dart';
import 'cari_adres_repository.dart';
import 'mock_cari_repository.dart';

/// In-memory address API with the same rules and `MessageCode`s as the real
/// one (`docs/api-contract.md` §6A). A few seeded addresses; changes live as
/// long as the repository does. Cari ids follow [MockCariRepository]: every
/// 9th is linked to Netsis, so its addresses are read-only.
class MockCariAdresRepository implements CariAdresRepository {
  MockCariAdresRepository() {
    _add(1, 1, il: 'İstanbul', ilce: 'Kadıköy', mahalle: 'Caferağa Mah.');
    _add(
      1,
      2,
      il: 'İzmir',
      ilce: 'Bornova',
      mahalle: 'Kazımdirik Mah.',
      cadde: '1203/1 Sok.',
      disKapi: '14',
      icKapi: '3',
      adres: 'Kazımdirik Mah. 1203/1 Sok. No: 14 D: 3',
      postaKodu: '35100',
    );
    _add(
      2,
      1,
      il: 'Ankara',
      ilce: 'Çankaya',
      cadde: 'Atatürk Bulvarı',
      disKapi: '120',
      adres: 'Atatürk Bulvarı No: 120',
      postaKodu: '06680',
    );
    // Linked to Netsis: read-only.
    _add(
      9,
      1,
      il: 'Bursa',
      ilce: 'Nilüfer',
      mahalle: 'Özlüce Mah.',
      adres: 'Özlüce Mah. Fabrika Cad. No: 7',
      postaKodu: '16120',
    );
  }

  static const _types = [
    AdresTipi(1, 'Fatura adresi'),
    AdresTipi(2, 'Sevkiyat adresi'),
    AdresTipi(3, 'Merkez adresi'),
  ];

  final _records = <int, CariAdres>{};
  var _nextId = 1;

  void _add(
    int cariId,
    int tipiId, {
    String il = '',
    String ilce = '',
    String mahalle = '',
    String cadde = '',
    String disKapi = '',
    String icKapi = '',
    String adres = '',
    String postaKodu = '',
  }) {
    final id = _nextId++;
    _records[id] = CariAdres(
      id: id,
      cariId: cariId,
      adresTipiId: tipiId,
      adresTipi: _typeName(tipiId),
      il: il,
      ilce: ilce,
      mahalle: mahalle,
      cadde: cadde,
      disKapi: disKapi,
      icKapi: icKapi,
      adres: adres,
      postaKodu: postaKodu,
    );
  }

  static String _typeName(int? id) {
    for (final type in _types) {
      if (type.id == id) return type.ad;
    }
    return '';
  }

  static ApiFailure<T> _rule<T>(int code, [String? message]) => ApiFailure<T>(
    httpStatus: 200,
    messageCode: code,
    message: message ?? 'mock $code',
  );

  @override
  Future<ApiResult<CariAdresList>> list(int cariId) async {
    if (cariId <= 0) return _rule(1004);
    return ApiSuccess(
      CariAdresList(
        items: [
          for (final id in _records.keys.toList()..sort())
            if (_records[id]!.cariId == cariId) _records[id]!,
        ],
        netsisBagli: MockCariRepository.isNetsisLinked(cariId),
      ),
    );
  }

  @override
  Future<ApiResult<int>> save(CariAdres adres, IntegrationType type) async {
    if (adres.cariId <= 0) return _rule(1003);
    final isNew = adres.id == null || adres.id == 0;
    final existing = isNew ? null : _records[adres.id];
    if (!isNew && existing == null) return _rule(1004);
    if (existing != null && existing.cariId != adres.cariId) return _rule(1003);
    if (MockCariRepository.isNetsisLinked(adres.cariId)) return _rule(1203);

    final issues = validateAdres(adres, type);
    if (adres.adresTipiId == null) return _rule(1002);
    if (!_types.any((t) => t.id == adres.adresTipiId)) return _rule(1003);
    if (issues[AdresField.postaKodu] != null ||
        issues.values.contains(AdresIssue.tooLong)) {
      return _rule(1003);
    }
    if (issues.isNotEmpty) return _rule(1002);

    // Fields outside the tenant's set are ignored: NULL for a new address,
    // the stored value for an update.
    final sent = adres.forTenant(type);
    final fields = adresFieldsFor(type);
    String pick(AdresField f) =>
        fields.contains(f) ? sent.valueOf(f) : (existing?.valueOf(f) ?? '');
    final id = existing?.id ?? _nextId++;
    _records[id] = CariAdres(
      id: id,
      cariId: adres.cariId,
      adresTipiId: adres.adresTipiId,
      adresTipi: _typeName(adres.adresTipiId),
      il: pick(AdresField.il),
      ilce: pick(AdresField.ilce),
      mahalle: pick(AdresField.mahalle),
      cadde: pick(AdresField.cadde),
      disKapi: pick(AdresField.disKapi),
      icKapi: pick(AdresField.icKapi),
      adres: pick(AdresField.adres),
      postaKodu: pick(AdresField.postaKodu),
    );
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<void>> delete(int id) async {
    final record = _records[id];
    if (record == null) return _rule(1004);
    if (MockCariRepository.isNetsisLinked(record.cariId)) return _rule(1203);
    _records.remove(id);
    return const ApiSuccess<void>(null);
  }

  @override
  Future<ApiResult<List<AdresTipi>>> tipler() async => const ApiSuccess(_types);
}
