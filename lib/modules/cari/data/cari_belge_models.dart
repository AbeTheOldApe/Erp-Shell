import 'package:flutter/foundation.dart';

import '../../../core/utils/decimal_units.dart';

/// Limits of the document form (`docs/api-contract.md` §6B.3.4, §6B.4).
abstract final class CariBelgeLimits {
  static const belgeNo = 20;
  static const kalemler = 200;
  static const tutarDecimals = 2;
  static const miktarDecimals = 4;
}

/// A document type; `sign` is its effect on the Cari balance (stored only).
@immutable
class BelgeTipi {
  const BelgeTipi(this.id, this.ad, [this.sign = 0]);

  final int id;
  final String ad;
  final int sign;
}

@immutable
class BelgeDoviz {
  const BelgeDoviz(this.id, this.kod, [this.simge = '']);

  final int id;
  final String kod;
  final String simge;
}

@immutable
class BelgeBirim {
  const BelgeBirim(this.id, this.ad);

  final int id;
  final String ad;
}

@immutable
class BelgeVade {
  const BelgeVade(this.id, this.ad, [this.gun = 0]);

  final int id;
  final String ad;
  final int gun;
}

/// The fixed lists of the document form (`GET /fi/cari-belge-secenekleri`).
@immutable
class BelgeSecenekleri {
  const BelgeSecenekleri({
    required this.tipler,
    required this.dovizler,
    required this.birimler,
    required this.vadeler,
  });

  /// Active types only.
  final List<BelgeTipi> tipler;
  final List<BelgeDoviz> dovizler;
  final List<BelgeBirim> birimler;
  final List<BelgeVade> vadeler;

  /// Default currency: `DovizBirimiId` 1 (TL) if listed, else the first.
  BelgeDoviz? get varsayilanDoviz => _idOrFirst(dovizler, (d) => d.id);

  /// Default term: `OdemeVadeId` 1 (Peşin) if listed, else the first.
  BelgeVade? get varsayilanVade => _idOrFirst(vadeler, (v) => v.id);

  /// Default unit: "Adet", else `BirimId` 1, else the first.
  BelgeBirim? get varsayilanBirim {
    for (final b in birimler) {
      if (b.ad.toLowerCase() == 'adet') return b;
    }
    return _idOrFirst(birimler, (b) => b.id);
  }

  static T? _idOrFirst<T>(List<T> list, int Function(T) id) {
    for (final item in list) {
      if (id(item) == 1) return item;
    }
    return list.isEmpty ? null : list.first;
  }
}

/// A row of the document list.
@immutable
class BelgeOzet {
  const BelgeOzet({
    required this.id,
    required this.tipi,
    this.no = '',
    required this.tarih,
    this.dovizKodu = '',
    this.kalemSayisi = 0,
    this.toplamKurus = 0,
  });

  final int id;
  final String tipi;

  /// Empty when the document has no number.
  final String no;
  final DateTime tarih;
  final String dovizKodu;
  final int kalemSayisi;

  /// Sum of the line amounts in kuruş.
  final int toplamKurus;
}

@immutable
class BelgeListe {
  const BelgeListe({required this.items, required this.total});

  final List<BelgeOzet> items;
  final int total;
}

/// A document line. [miktar] is in 1/10000, [tutar] in kuruş (`null` in old
/// migrated records).
@immutable
class BelgeKalem {
  const BelgeKalem({
    this.id,
    this.stokKartiId,
    this.miktar = 10000,
    required this.birimId,
    this.birim = '',
    this.tutar,
  });

  /// Null for a new line.
  final int? id;
  final int? stokKartiId;
  final int miktar;
  final int? birimId;
  final String birim;
  final int? tutar;
}

/// A document with its lines.
@immutable
class CariBelge {
  const CariBelge({
    this.id,
    required this.cariId,
    required this.tipiId,
    this.tipi = '',
    this.no = '',
    required this.tarih,
    required this.dovizId,
    this.dovizKodu = '',
    this.vadeId,
    this.kalemler = const [],
  });

  /// Null for a new document.
  final int? id;
  final int cariId;
  final int? tipiId;

  /// Name of the type as the API returns it (also for an inactive type).
  final String tipi;
  final String no;
  final DateTime tarih;
  final int? dovizId;
  final String dovizKodu;
  final int? vadeId;
  final List<BelgeKalem> kalemler;

  /// Sum of the line amounts in kuruş; an empty amount counts 0.
  int get toplamKurus => sumKurus(kalemler.map((k) => k.tutar));
}

/// Exact sum of amounts in kuruş.
int sumKurus(Iterable<int?> amounts) =>
    amounts.fold<int>(0, (sum, a) => sum + (a ?? 0));

final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `yyyy-MM-dd` of the calendar day of [date]. Built from its parts, so no
/// time zone can move the day.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// The calendar day of a `yyyy-MM-dd` text (local midnight), or `null`.
DateTime? parseIsoDate(Object? text) {
  final match = text is String ? _isoDate.firstMatch(text.trim()) : null;
  if (match == null) return null;
  final y = int.parse(match[1]!);
  final m = int.parse(match[2]!);
  final d = int.parse(match[3]!);
  final date = DateTime(y, m, d);
  // Rejects 2026-02-30 (which DateTime would roll over to March).
  return date.year == y && date.month == m && date.day == d ? date : null;
}

/// What is wrong with a value.
enum BelgeIssue {
  required,
  tooLong,
  invalidNumber,
  tooManyDecimals,
  tooLarge,
  notPositive,
  negative,
  atLeastOneKalem,
  tooManyKalem,
}

/// Header fields of the document form; [form] is the form as a whole.
enum BelgeField { tipi, tarih, no, doviz, vade, form }

/// Fields of a line.
enum KalemField { miktar, birim, tutar }

/// Quantity text: > 0, at most 4 decimals. Empty is not allowed in the form
/// (it starts as 1).
BelgeIssue? checkMiktar(String text) {
  final parsed = parseUnits(text, decimals: CariBelgeLimits.miktarDecimals);
  return switch (parsed.error) {
    UnitsError.empty => BelgeIssue.required,
    UnitsError.invalid => BelgeIssue.invalidNumber,
    UnitsError.tooManyDecimals => BelgeIssue.tooManyDecimals,
    UnitsError.tooLarge => BelgeIssue.tooLarge,
    null => parsed.value! <= 0 ? BelgeIssue.notPositive : null,
  };
}

/// Amount text: required, >= 0 (0 is valid), at most 2 decimals.
BelgeIssue? checkTutar(String text) {
  final parsed = parseUnits(text, decimals: CariBelgeLimits.tutarDecimals);
  return switch (parsed.error) {
    UnitsError.empty => BelgeIssue.required,
    UnitsError.invalid => BelgeIssue.invalidNumber,
    UnitsError.tooManyDecimals => BelgeIssue.tooManyDecimals,
    UnitsError.tooLarge => BelgeIssue.tooLarge,
    null => parsed.value! < 0 ? BelgeIssue.negative : null,
  };
}

/// Document number: optional, at most 20 characters.
BelgeIssue? checkBelgeNo(String text) =>
    text.trim().length > CariBelgeLimits.belgeNo ? BelgeIssue.tooLong : null;

/// A line as typed in the form.
@immutable
class KalemDraft {
  const KalemDraft({
    this.id,
    this.stokKartiId,
    this.miktar = '1',
    this.birimId,
    this.tutar = '',
  });

  final int? id;
  final int? stokKartiId;
  final String miktar;
  final int? birimId;
  final String tutar;
}

/// A document as typed in the form.
@immutable
class BelgeDraft {
  const BelgeDraft({
    this.id,
    required this.cariId,
    this.tipiId,
    this.no = '',
    this.tarih,
    this.dovizId,
    this.vadeId,
    this.kalemler = const [],
  });

  final int? id;
  final int cariId;
  final int? tipiId;
  final String no;
  final DateTime? tarih;
  final int? dovizId;
  final int? vadeId;
  final List<KalemDraft> kalemler;

  bool get isNew => id == null || id == 0;
}

/// Result of [validateBelge].
@immutable
class BelgeValidation {
  const BelgeValidation(this.header, this.rows);

  final Map<BelgeField, BelgeIssue> header;

  /// One map per line, in order.
  final List<Map<KalemField, BelgeIssue>> rows;

  bool get isValid => header.isEmpty && rows.every((r) => r.isEmpty);
}

/// The server's rules (`docs/api-contract.md` §6B.3.4), checked on the
/// client. The server checks again.
BelgeValidation validateBelge(BelgeDraft draft) {
  final header = <BelgeField, BelgeIssue>{};
  if (draft.tipiId == null) header[BelgeField.tipi] = BelgeIssue.required;
  if (draft.tarih == null) header[BelgeField.tarih] = BelgeIssue.required;
  if (draft.dovizId == null) header[BelgeField.doviz] = BelgeIssue.required;
  final noIssue = checkBelgeNo(draft.no);
  if (noIssue != null) header[BelgeField.no] = noIssue;
  if (draft.isNew && draft.kalemler.isEmpty) {
    header[BelgeField.form] = BelgeIssue.atLeastOneKalem;
  }
  if (draft.kalemler.length > CariBelgeLimits.kalemler) {
    header[BelgeField.form] = BelgeIssue.tooManyKalem;
  }
  final rows = [
    for (final kalem in draft.kalemler)
      {
        KalemField.miktar: ?checkMiktar(kalem.miktar),
        if (kalem.birimId == null) KalemField.birim: BelgeIssue.required,
        KalemField.tutar: ?checkTutar(kalem.tutar),
      },
  ];
  return BelgeValidation(header, rows);
}

/// The document of a valid [draft]. [tipi] and [dovizKodu] are display
/// names only.
CariBelge belgeFromDraft(BelgeDraft draft) => CariBelge(
  id: draft.id,
  cariId: draft.cariId,
  tipiId: draft.tipiId,
  no: draft.no.trim(),
  tarih: draft.tarih!,
  dovizId: draft.dovizId,
  vadeId: draft.vadeId,
  kalemler: [
    for (final k in draft.kalemler)
      BelgeKalem(
        id: k.id,
        stokKartiId: k.stokKartiId,
        miktar: parseUnits(
          k.miktar,
          decimals: CariBelgeLimits.miktarDecimals,
        ).value!,
        birimId: k.birimId,
        tutar: parseUnits(
          k.tutar,
          decimals: CariBelgeLimits.tutarDecimals,
        ).value!,
      ),
  ],
);
