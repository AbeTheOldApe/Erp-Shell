import '../../../core/auth/auth_models.dart';
import '../../../core/network/api_result.dart';
import 'cari_belge_models.dart';
import 'cari_belge_repository.dart';

/// In-memory document API with the same rules and `MessageCode`s as the real
/// one (`docs/api-contract.md` §6B). Cari 1 has a single-line, a multi-line,
/// a line-less and an inactive-type document; Cari 3 has 60 documents (paging);
/// Cari 9 (Netsis) has one with a stock card. Changes live as long as the
/// repository does.
class MockCariBelgeRepository implements CariBelgeRepository {
  MockCariBelgeRepository() {
    _add(
      1,
      tipiId: 1,
      no: 'A-1',
      tarih: DateTime(2026, 1, 2),
      kalemler: [const BelgeKalem(birimId: 1, tutar: 12345)],
    );
    _add(
      1,
      tipiId: 2,
      no: 'F-100',
      tarih: DateTime(2026, 3, 15),
      dovizId: 2,
      vadeId: 2,
      kalemler: [
        const BelgeKalem(miktar: 100000, birimId: 1, tutar: 10010),
        const BelgeKalem(miktar: 25000, birimId: 2, tutar: 3333),
        const BelgeKalem(birimId: 3, tutar: 0),
      ],
    );
    _add(1, tipiId: 1, tarih: DateTime(2026, 2, 1));
    _add(
      1,
      tipiId: _inactiveTypeId,
      no: 'ESKI-7',
      tarih: DateTime(2025, 12, 31),
      kalemler: [const BelgeKalem(birimId: 1, tutar: 50000)],
    );
    for (var i = 1; i <= 60; i++) {
      _add(
        3,
        tipiId: i.isEven ? 1 : 2,
        no: 'B-$i',
        tarih: DateTime(2026, 1 + (i - 1) % 9, 1 + i % 28),
        kalemler: [BelgeKalem(birimId: 1, tutar: i * 150)],
      );
    }
    _add(
      9,
      tipiId: 1,
      no: 'N-1',
      tarih: DateTime(2026, 4, 4),
      kalemler: [const BelgeKalem(stokKartiId: 4242, birimId: 1, tutar: 99900)],
    );
  }

  static const _inactiveTypeId = 99;

  static const _secenekler = BelgeSecenekleri(
    tipler: [
      BelgeTipi(1, 'Açılış', 1),
      BelgeTipi(2, 'Satış Faturası', 1),
      BelgeTipi(3, 'Alış Faturası', -1),
      BelgeTipi(4, 'Tahsilat', -1),
    ],
    dovizler: [
      BelgeDoviz(1, 'TRL', '₺'),
      BelgeDoviz(2, 'USD', r'$'),
      BelgeDoviz(3, 'EUR', '€'),
    ],
    birimler: [BelgeBirim(1, 'Adet'), BelgeBirim(2, 'Kg'), BelgeBirim(3, 'Lt')],
    vadeler: [
      BelgeVade(1, 'Peşin', 0),
      BelgeVade(2, '30 gün', 30),
      BelgeVade(3, '60 gün', 60),
    ],
  );

  final _records = <int, CariBelge>{};
  var _nextId = 1;
  var _nextKalemId = 1;
  final _deleted = <int>{};

  void _add(
    int cariId, {
    required int tipiId,
    String no = '',
    required DateTime tarih,
    int dovizId = 1,
    int vadeId = 1,
    List<BelgeKalem> kalemler = const [],
  }) {
    final id = _nextId++;
    _records[id] = _build(
      id: id,
      cariId: cariId,
      tipiId: tipiId,
      no: no,
      tarih: tarih,
      dovizId: dovizId,
      vadeId: vadeId,
      kalemler: [
        for (final k in kalemler)
          BelgeKalem(
            id: _nextKalemId++,
            stokKartiId: k.stokKartiId,
            miktar: k.miktar,
            birimId: k.birimId,
            tutar: k.tutar,
          ),
      ],
    );
  }

  CariBelge _build({
    required int id,
    required int cariId,
    required int? tipiId,
    required String no,
    required DateTime tarih,
    required int? dovizId,
    required int? vadeId,
    required List<BelgeKalem> kalemler,
  }) => CariBelge(
    id: id,
    cariId: cariId,
    tipiId: tipiId,
    tipi: tipiId == _inactiveTypeId
        ? 'Eski Fatura'
        : _secenekler.tipler.where((t) => t.id == tipiId).firstOrNull?.ad ?? '',
    no: no,
    tarih: tarih,
    dovizId: dovizId,
    dovizKodu:
        _secenekler.dovizler.where((d) => d.id == dovizId).firstOrNull?.kod ??
        '',
    vadeId: vadeId,
    kalemler: [
      for (final k in kalemler)
        BelgeKalem(
          id: k.id,
          stokKartiId: k.stokKartiId,
          miktar: k.miktar,
          birimId: k.birimId,
          birim:
              _secenekler.birimler
                  .where((b) => b.id == k.birimId)
                  .firstOrNull
                  ?.ad ??
              '',
          tutar: k.tutar,
        ),
    ],
  );

  static ApiFailure<T> _rule<T>(int code) =>
      ApiFailure<T>(httpStatus: 200, messageCode: code, message: 'mock $code');

  @override
  Future<ApiResult<BelgeListe>> list(
    int cariId, {
    int page = 1,
    int pageSize = 25,
  }) async {
    if (cariId <= 0) return _rule(1004);
    final all =
        [
          for (final b in _records.values)
            if (b.cariId == cariId) b,
        ]..sort((a, b) {
          final byDate = b.tarih.compareTo(a.tarih);
          return byDate != 0 ? byDate : b.id!.compareTo(a.id!);
        });
    final size = pageSize.clamp(1, 200);
    final start = ((page < 1 ? 1 : page) - 1) * size;
    return ApiSuccess(
      BelgeListe(
        items: [
          for (final b in all.skip(start).take(size))
            BelgeOzet(
              id: b.id!,
              tipi: b.tipi,
              no: b.no,
              tarih: b.tarih,
              dovizKodu: b.dovizKodu,
              kalemSayisi: b.kalemler.length,
              toplamKurus: b.toplamKurus,
            ),
        ],
        total: all.length,
      ),
    );
  }

  @override
  Future<ApiResult<CariBelge>> get(int id) async {
    final record = _records[id];
    return record == null ? _rule(1004) : ApiSuccess(record);
  }

  @override
  Future<ApiResult<int>> save(CariBelge belge, IntegrationType type) async {
    if (belge.cariId <= 0) return _rule(1002);
    final isNew = belge.id == null || belge.id == 0;
    final existing = isNew ? null : _records[belge.id];
    if (!isNew && existing == null) return _rule(1004);
    if (existing != null && existing.cariId != belge.cariId) return _rule(1003);

    if (belge.tipiId == null || belge.dovizId == null) return _rule(1002);
    final activeType = _secenekler.tipler.any((t) => t.id == belge.tipiId);
    // A document of an inactive type may stay in it, not move to one.
    if (!activeType && belge.tipiId != existing?.tipiId) return _rule(1003);
    if (!_secenekler.dovizler.any((d) => d.id == belge.dovizId)) {
      return _rule(1003);
    }
    if (belge.vadeId != null &&
        !_secenekler.vadeler.any((v) => v.id == belge.vadeId)) {
      return _rule(1003);
    }
    if (belge.no.trim().length > CariBelgeLimits.belgeNo) return _rule(1003);
    if (isNew && belge.kalemler.isEmpty) return _rule(1002);
    if (belge.kalemler.length > CariBelgeLimits.kalemler) return _rule(1003);

    final stored = <int, BelgeKalem>{
      for (final k in existing?.kalemler ?? <BelgeKalem>[]) k.id!: k,
    };
    final kalemler = <BelgeKalem>[];
    for (final k in belge.kalemler) {
      if (k.birimId == null || k.tutar == null) return _rule(1002);
      if (!_secenekler.birimler.any((b) => b.id == k.birimId)) {
        return _rule(1003);
      }
      if (k.miktar <= 0 || k.tutar! < 0) return _rule(1003);
      final hasId = k.id != null && k.id! > 0;
      final old = hasId ? stored[k.id] : null;
      if (hasId && old == null) return _rule(1003);
      kalemler.add(
        BelgeKalem(
          id: old?.id ?? _nextKalemId++,
          // The stock card is written by the Netsis set only; otherwise a
          // new line has none and an existing one keeps its value.
          stokKartiId: type == IntegrationType.netsis
              ? k.stokKartiId
              : old?.stokKartiId,
          miktar: k.miktar,
          birimId: k.birimId,
          tutar: k.tutar,
        ),
      );
    }

    final id = existing?.id ?? _nextId++;
    _records[id] = _build(
      id: id,
      cariId: belge.cariId,
      tipiId: belge.tipiId,
      no: belge.no.trim(),
      tarih: belge.tarih,
      dovizId: belge.dovizId,
      vadeId: belge.vadeId ?? existing?.vadeId ?? 1,
      kalemler: kalemler,
    );
    return ApiSuccess(id);
  }

  @override
  Future<ApiResult<void>> delete(int id) async {
    if (_deleted.contains(id)) return _rule(1005);
    if (!_records.containsKey(id)) return _rule(1004);
    _records.remove(id);
    _deleted.add(id);
    return const ApiSuccess<void>(null);
  }

  @override
  Future<ApiResult<BelgeSecenekleri>> secenekler() async =>
      const ApiSuccess(_secenekler);
}
