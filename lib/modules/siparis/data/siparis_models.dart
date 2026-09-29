import 'package:flutter/foundation.dart';

/// Order status. [apiValue] is what the API sends and filters on.
enum SiparisDurum {
  acik('Acik'),
  onaylandi('Onaylandi'),
  sevkEdildi('SevkEdildi'),
  iptal('Iptal');

  const SiparisDurum(this.apiValue);

  final String apiValue;

  static SiparisDurum fromApi(String value) =>
      values.firstWhere((d) => d.apiValue == value, orElse: () => acik);
}

/// A row of the order list (`POST /siparisler/query` items).
@immutable
class SiparisOzet {
  const SiparisOzet({
    required this.id,
    required this.no,
    required this.musteri,
    required this.tarih,
    required this.durum,
    required this.tutar,
  });

  factory SiparisOzet.fromJson(Map<String, dynamic> json) => SiparisOzet(
    id: json['id'] as int,
    no: json['no'] as String,
    musteri: json['musteri'] as String,
    tarih: DateTime.parse(json['tarih'] as String),
    durum: SiparisDurum.fromApi(json['durum'] as String),
    tutar: (json['tutar'] as num).toDouble(),
  );

  final int id;
  final String no;
  final String musteri;
  final DateTime tarih;
  final SiparisDurum durum;
  final double tutar;
}

@immutable
class SiparisKalemi {
  const SiparisKalemi({
    required this.urun,
    required this.miktar,
    required this.birimFiyat,
  });

  factory SiparisKalemi.fromJson(Map<String, dynamic> json) => SiparisKalemi(
    urun: json['urun'] as String,
    miktar: (json['miktar'] as num).toDouble(),
    birimFiyat: (json['birimFiyat'] as num).toDouble(),
  );

  final String urun;
  final double miktar;
  final double birimFiyat;

  double get tutar => miktar * birimFiyat;

  Map<String, dynamic> toJson() => {
    'urun': urun,
    'miktar': miktar,
    'birimFiyat': birimFiyat,
  };
}

/// An order with its lines (`GET /siparisler/{id}`). `id == null` for a
/// new order; `no` is assigned by the server.
@immutable
class Siparis {
  const Siparis({
    required this.musteri,
    required this.tarih,
    required this.durum,
    this.id,
    this.no = '',
    this.teslimAdresi = '',
    this.not = '',
    this.kalemler = const [],
  });

  factory Siparis.fromJson(Map<String, dynamic> json) => Siparis(
    id: json['id'] as int?,
    no: json['no'] as String? ?? '',
    musteri: json['musteri'] as String,
    tarih: DateTime.parse(json['tarih'] as String),
    durum: SiparisDurum.fromApi(json['durum'] as String),
    teslimAdresi: json['teslimAdresi'] as String? ?? '',
    not: json['not'] as String? ?? '',
    kalemler: [
      for (final k in json['kalemler'] as List<dynamic>? ?? [])
        SiparisKalemi.fromJson(k as Map<String, dynamic>),
    ],
  );

  final int? id;
  final String no;
  final String musteri;
  final DateTime tarih;
  final SiparisDurum durum;
  final String teslimAdresi;
  final String not;
  final List<SiparisKalemi> kalemler;

  double get tutar => kalemler.fold(0, (sum, k) => sum + k.tutar);

  SiparisOzet get ozet => SiparisOzet(
    id: id!,
    no: no,
    musteri: musteri,
    tarih: tarih,
    durum: durum,
    tutar: tutar,
  );

  Siparis copyWith({int? id, String? no}) => Siparis(
    id: id ?? this.id,
    no: no ?? this.no,
    musteri: musteri,
    tarih: tarih,
    durum: durum,
    teslimAdresi: teslimAdresi,
    not: not,
    kalemler: kalemler,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'no': no,
    'musteri': musteri,
    'tarih':
        '${tarih.year.toString().padLeft(4, '0')}-'
        '${tarih.month.toString().padLeft(2, '0')}-'
        '${tarih.day.toString().padLeft(2, '0')}',
    'durum': durum.apiValue,
    'teslimAdresi': teslimAdresi,
    'not': not,
    'kalemler': [for (final k in kalemler) k.toJson()],
  };
}
