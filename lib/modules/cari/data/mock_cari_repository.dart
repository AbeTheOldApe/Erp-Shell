import '../../../core/network/api_result.dart';
import '../../../core/utils/turkish_fold.dart';
import '../../../shared/app_data_grid/grid_query.dart';
import 'cari_models.dart';
import 'cari_repository.dart';

/// In-memory Cari API with the same rules and `MessageCode`s as the real one
/// (`docs/api-contract.md` §6). About 60 deterministic records; changes live
/// as long as the repository does.
class MockCariRepository implements CariRepository {
  MockCariRepository() {
    for (var i = 1; i <= 60; i++) {
      _records[i] = _seed(i);
    }
    _nextId = 61;
  }

  static const _names = [
    'Anadolu Gıda',
    'Bora Tekstil',
    'Cem Elektronik',
    'Deniz Lojistik',
    'Efe Yapı',
    'Güneş Enerji',
    'İpek Mobilya',
    'Işık Aydınlatma',
    'Özkan Otomotiv',
    'Şahin Kimya',
  ];

  static const _suffixes = ['A.Ş.', 'Ltd. Şti.', 'San. ve Tic.'];

  final _records = <int, Cari>{};
  late int _nextId;

  /// Every 7th is passive, every 9th is linked to Netsis.
  static Cari _seed(int i) {
    final name = '${_names[i % _names.length]} ${_suffixes[i % 3]}';
    final person = i % 5 == 0;
    return Cari(
      id: i,
      kod: 'C${i.toString().padLeft(4, '0')}',
      cari: name,
      unvan: name,
      kisaUnvan: _names[i % _names.length],
      webAdresi: 'www.firma$i.example',
      ePosta: 'info@firma$i.example',
      telefon: '0212 555 ${(1000 + i).toString()}',
      faks: i % 4 == 0 ? '0212 556 ${(1000 + i).toString()}' : '',
      vergiDairesi: person ? '' : 'Kadıköy',
      vergiNo: person ? '' : (1000000000 + i * 7919).toString(),
      tcKimlikNo: person ? (10000000000 + i * 104729).toString() : '',
      musteri: i % 2 == 0,
      urunTedarikcisi: i % 3 == 0,
      hizmetTedarikcisi: i % 4 == 0,
      otomatikEkstre: i % 6 == 0,
      aktif: i % 7 != 0,
      netsisBagli: i % 9 == 0,
    );
  }

  static ApiFailure<T> _rule<T>(int code) =>
      ApiFailure<T>(httpStatus: 200, messageCode: code, message: 'mock $code');

  @override
  Future<ApiResult<GridPage<CariOzet>>> list(GridQuery query) async {
    String? text;
    var musteri = false, urun = false, hizmet = false, pasif = false;
    for (final f in query.filters) {
      switch (f.field) {
        case CariFilters.arama when f.op == FilterOp.contains:
          text = turkishFold('${f.value}'.trim());
        case CariFilters.musteri:
          musteri = f.value == true;
        case CariFilters.urunTedarikcisi:
          urun = f.value == true;
        case CariFilters.hizmetTedarikcisi:
          hizmet = f.value == true;
        case CariFilters.pasif:
          pasif = f.value == true;
      }
    }
    bool matches(Cari c) {
      if (!pasif && !c.aktif) return false;
      if (musteri && !c.musteri) return false;
      if (urun && !c.urunTedarikcisi) return false;
      if (hizmet && !c.hizmetTedarikcisi) return false;
      if (text != null && text.isNotEmpty) {
        final haystack = turkishFold(
          [
            c.kod,
            c.unvan,
            c.kisaUnvan,
            c.cari,
            c.vergiNo,
            c.tcKimlikNo,
          ].join(' '),
        );
        if (!haystack.contains(text)) return false;
      }
      return true;
    }

    // The real API has a fixed order and no sorting.
    final all = [
      for (final id in _records.keys.toList()..sort())
        if (matches(_records[id]!)) _records[id]!,
    ];
    final pageSize = query.pageSize.clamp(1, 200);
    final start = ((query.page < 1 ? 1 : query.page) - 1) * pageSize;
    final items = all.skip(start).take(pageSize).map((c) => c.toOzet());
    return ApiSuccess(GridPage(items: items.toList(), total: all.length));
  }

  @override
  Future<ApiResult<Cari>> get(int id) async {
    final record = _records[id];
    return record == null ? _rule(1004) : ApiSuccess(record);
  }

  @override
  Future<ApiResult<int>> save(Cari cari) async {
    if (cari.unvan.trim().isEmpty) return _rule(1002);
    final existing = cari.id == null || cari.id == 0 ? null : _records[cari.id];
    if (cari.id != null && cari.id != 0 && existing == null) {
      return _rule(1004);
    }
    if (existing != null && existing.netsisBagli) return _rule(1203);

    final id = existing?.id ?? _nextId;
    final kod = cari.kod.trim();
    if (kod.isNotEmpty &&
        _records.values.any((c) => c.id != id && c.kod == kod)) {
      return _rule(1201);
    }
    for (final number in [cari.vergiNo.trim(), cari.tcKimlikNo.trim()]) {
      if (number.isNotEmpty &&
          _records.values.any(
            (c) =>
                c.id != id && (c.vergiNo == number || c.tcKimlikNo == number),
          )) {
        return _rule(1202);
      }
    }

    if (existing == null) _nextId++;
    _records[id] = Cari(
      id: id,
      kod: kod,
      cari: cari.cari.trim(),
      unvan: cari.unvan.trim(),
      kisaUnvan: cari.kisaUnvan.trim(),
      webAdresi: cari.webAdresi.trim(),
      ePosta: cari.ePosta.trim(),
      telefon: cari.telefon.trim(),
      faks: cari.faks.trim(),
      vergiDairesi: cari.vergiDairesi.trim(),
      vergiNo: cari.vergiNo.trim(),
      tcKimlikNo: cari.tcKimlikNo.trim(),
      musteri: cari.musteri,
      urunTedarikcisi: cari.urunTedarikcisi,
      hizmetTedarikcisi: cari.hizmetTedarikcisi,
      otomatikEkstre: cari.otomatikEkstre,
      aktif: existing?.aktif ?? true,
    );
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<void>> delete(int id) async {
    final record = _records[id];
    if (record == null) return _rule(1004);
    if (record.netsisBagli) return _rule(1203);
    if (!record.aktif) return _rule(1005);
    // Soft delete: the record stays, as a passive one.
    _records[id] = record.copyWith(aktif: false);
    return const ApiSuccess<void>(null);
  }
}
