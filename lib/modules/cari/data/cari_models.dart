import 'package:flutter/foundation.dart';

/// Filter field names of the Cari list (`GridFilter.field`).
abstract final class CariFilters {
  static const arama = 'arama';
  static const musteri = 'musteri';
  static const urunTedarikcisi = 'urunTedarikcisi';
  static const hizmetTedarikcisi = 'hizmetTedarikcisi';
  static const pasif = 'pasif';
}

/// Maximum lengths of the form fields (`docs/api-contract.md` §6.3).
abstract final class CariLimits {
  static const unvan = 100;
  static const cari = 100;
  static const kod = 15;
  static const kisaUnvan = 50;
  static const webAdresi = 60;
  static const ePosta = 255;
  static const telefon = 20;
  static const faks = 20;
  static const vergiDairesi = 50;
  static const vergiNo = 15;
  static const tcKimlikNo = 11;
}

/// A row of the Cari list.
@immutable
class CariOzet {
  const CariOzet({
    required this.id,
    required this.kod,
    required this.unvan,
    this.kisaUnvan = '',
    this.telefon = '',
    this.ePosta = '',
    this.vergiNo = '',
    this.tcKimlikNo = '',
    this.musteri = false,
    this.urunTedarikcisi = false,
    this.hizmetTedarikcisi = false,
    this.aktif = true,
    this.netsisBagli = false,
  });

  final int id;
  final String kod;
  final String unvan;
  final String kisaUnvan;
  final String telefon;
  final String ePosta;
  final String vergiNo;
  final String tcKimlikNo;
  final bool musteri;
  final bool urunTedarikcisi;
  final bool hizmetTedarikcisi;
  final bool aktif;
  final bool netsisBagli;

  /// Tax number, or the national ID when there is none.
  String get vergiTc => vergiNo.isNotEmpty ? vergiNo : tcKimlikNo;
}

/// A Cari with every form field. [id] is null for a new one.
@immutable
class Cari {
  const Cari({
    this.id,
    this.kod = '',
    this.cari = '',
    required this.unvan,
    this.kisaUnvan = '',
    this.webAdresi = '',
    this.ePosta = '',
    this.telefon = '',
    this.faks = '',
    this.vergiDairesi = '',
    this.vergiNo = '',
    this.tcKimlikNo = '',
    this.musteri = false,
    this.urunTedarikcisi = false,
    this.hizmetTedarikcisi = false,
    this.otomatikEkstre = false,
    this.aktif = true,
    this.netsisBagli = false,
  });

  final int? id;
  final String kod;
  final String cari;
  final String unvan;
  final String kisaUnvan;
  final String webAdresi;
  final String ePosta;
  final String telefon;
  final String faks;
  final String vergiDairesi;
  final String vergiNo;
  final String tcKimlikNo;
  final bool musteri;
  final bool urunTedarikcisi;
  final bool hizmetTedarikcisi;
  final bool otomatikEkstre;

  /// Shown only; the API cannot change it.
  final bool aktif;

  /// Linked to Netsis: read-only, no save, no delete.
  final bool netsisBagli;

  CariOzet toOzet() => CariOzet(
    id: id!,
    kod: kod,
    unvan: unvan,
    kisaUnvan: kisaUnvan,
    telefon: telefon,
    ePosta: ePosta,
    vergiNo: vergiNo,
    tcKimlikNo: tcKimlikNo,
    musteri: musteri,
    urunTedarikcisi: urunTedarikcisi,
    hizmetTedarikcisi: hizmetTedarikcisi,
    aktif: aktif,
    netsisBagli: netsisBagli,
  );

  Cari copyWith({int? id, bool? aktif}) => Cari(
    id: id ?? this.id,
    kod: kod,
    cari: cari,
    unvan: unvan,
    kisaUnvan: kisaUnvan,
    webAdresi: webAdresi,
    ePosta: ePosta,
    telefon: telefon,
    faks: faks,
    vergiDairesi: vergiDairesi,
    vergiNo: vergiNo,
    tcKimlikNo: tcKimlikNo,
    musteri: musteri,
    urunTedarikcisi: urunTedarikcisi,
    hizmetTedarikcisi: hizmetTedarikcisi,
    otomatikEkstre: otomatikEkstre,
    aktif: aktif ?? this.aktif,
    netsisBagli: netsisBagli,
  );
}
