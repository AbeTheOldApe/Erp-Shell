import 'dart:convert';
import 'dart:math';

import '../../../core/network/api_exception.dart';
import '../../../data/mock/mock_backend.dart';
import '../../../shared/app_data_grid/grid_query.dart';
import '../../../shared/app_data_grid/local_grid_data_source.dart';
import 'siparis_models.dart';
import 'siparis_repository.dart';

/// In-memory orders API. Data is generated deterministically and lives for
/// the page session; it goes through JSON like the real API would.
class MockSiparisRepository implements SiparisRepository {
  MockSiparisRepository({
    required MockBackend backend,
    required String? Function() accessToken,
    int count = 137,
    DateTime? today,
  }) : _backend = backend,
       _accessToken = accessToken {
    _seed(count, today ?? DateTime(2026, 9, 28));
  }

  final MockBackend _backend;
  final String? Function() _accessToken;
  final Map<int, Map<String, dynamic>> _rows = {};
  int _nextId = 1;

  static const _customers = [
    'Ahmet Yılmaz Ltd.',
    'Beta Endüstri A.Ş.',
    'Çağ Gıda',
    'Deniz Lojistik',
    'Ege Tekstil',
    'Işık Elektrik',
    'İnci Mobilya',
    'Öz Yapı Market',
    'Şahin Otomotiv',
    'Ünal Kimya',
  ];

  static const _products = [
    ('Vida M8', 0.5),
    ('Somun M8', 0.3),
    ('Rulman 6204', 42.9),
    ('Kayış A-42', 118.0),
    ('Hidrolik yağ 20 L', 1450.0),
    ('Conta seti', 86.5),
    ('Filtre elemanı', 230.0),
    ('Kaynak teli 1 kg', 165.75),
  ];

  static const _cities = [
    'Kadıköy / İstanbul',
    'Çankaya / Ankara',
    'Bornova / İzmir',
    'Nilüfer / Bursa',
    'Şahinbey / Gaziantep',
  ];

  void _seed(int count, DateTime today) {
    final random = Random(42);
    const statuses = [
      SiparisDurum.acik,
      SiparisDurum.acik,
      SiparisDurum.onaylandi,
      SiparisDurum.onaylandi,
      SiparisDurum.sevkEdildi,
      SiparisDurum.sevkEdildi,
      SiparisDurum.sevkEdildi,
      SiparisDurum.iptal,
    ];
    SiparisKalemi randomKalem() {
      final (urun, fiyat) = _products[random.nextInt(_products.length)];
      return SiparisKalemi(
        urun: urun,
        // Cheap parts are ordered in bulk.
        miktar: (1 + random.nextInt(fiyat < 1 ? 500 : 20)).toDouble(),
        birimFiyat: fiyat,
      );
    }

    for (var i = 0; i < count; i++) {
      final lineCount = 1 + random.nextInt(5);
      final kalemler = [for (var k = 0; k < lineCount; k++) randomKalem()];
      _insert(
        Siparis(
          musteri: _customers[random.nextInt(_customers.length)],
          tarih: today.subtract(Duration(days: i ~/ 2)),
          durum: statuses[random.nextInt(statuses.length)],
          teslimAdresi: _cities[random.nextInt(_cities.length)],
          kalemler: kalemler,
        ),
      );
    }
  }

  Siparis _insert(Siparis siparis) {
    final id = _nextId++;
    final saved = siparis.copyWith(id: id, no: 'SP-${1000 + id}');
    _rows[id] = _roundTrip(saved.toJson());
    return saved;
  }

  /// Simulates serialization so no object is shared with the caller.
  static Map<String, dynamic> _roundTrip(Map<String, dynamic> json) =>
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

  Future<void> _call() async {
    await _backend.latency();
    _backend.authenticate(_accessToken());
  }

  @override
  Future<GridPage<SiparisOzet>> query(GridQuery query) async {
    await _call();
    // The request body travels as JSON.
    final request = GridQuery.fromJson(_roundTrip(query.toJson()));
    final all = [for (final row in _rows.values) Siparis.fromJson(row).ozet];
    return LocalGridDataSource<SiparisOzet>(
      all,
      fieldValue: (row, field) => switch (field) {
        'no' => row.no,
        'musteri' => row.musteri,
        'tarih' => row.tarih,
        'durum' => row.durum.apiValue,
        'tutar' => row.tutar,
        _ => null,
      },
    ).apply(request);
  }

  @override
  Future<Siparis> get(int id) async {
    await _call();
    final row = _rows[id];
    if (row == null) throw _notFound();
    return Siparis.fromJson(_roundTrip(row));
  }

  @override
  Future<Siparis> create(Siparis siparis) async {
    await _call();
    return _insert(Siparis.fromJson(_roundTrip(siparis.toJson())));
  }

  @override
  Future<Siparis> update(Siparis siparis) async {
    await _call();
    final id = siparis.id;
    if (id == null || !_rows.containsKey(id)) throw _notFound();
    _rows[id] = _roundTrip(siparis.toJson());
    return Siparis.fromJson(_roundTrip(_rows[id]!));
  }

  @override
  Future<void> delete(int id) async {
    await _call();
    if (_rows.remove(id) == null) throw _notFound();
  }

  static ApiException _notFound() =>
      const ApiException(statusCode: 404, code: 'not_found');
}
