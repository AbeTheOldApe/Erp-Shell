import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_models.dart';

/// Maximum lengths of the address fields (`docs/api-contract.md` §6A.3.3).
abstract final class CariAdresLimits {
  static const il = 25;
  static const ilce = 25;
  static const mahalle = 50;
  static const cadde = 50;
  static const disKapi = 25;
  static const icKapi = 25;
  static const adres = 255;
  static const postaKodu = 5;
}

/// Fields of the address form. [form] stands for the form as a whole (errors
/// that belong to no single field).
enum AdresField {
  adresTipi,
  il,
  ilce,
  mahalle,
  cadde,
  disKapi,
  icKapi,
  adres,
  postaKodu,
  form;

  int get maxLength => switch (this) {
    il => CariAdresLimits.il,
    ilce => CariAdresLimits.ilce,
    mahalle => CariAdresLimits.mahalle,
    cadde => CariAdresLimits.cadde,
    disKapi => CariAdresLimits.disKapi,
    icKapi => CariAdresLimits.icKapi,
    adres => CariAdresLimits.adres,
    postaKodu => CariAdresLimits.postaKodu,
    adresTipi || form => 0,
  };
}

/// The text fields of a tenant's address form, in display order
/// (`docs/api-contract.md` §6A.1). Fields outside the set are never sent.
List<AdresField> adresFieldsFor(IntegrationType type) => switch (type) {
  IntegrationType.yok => const [
    AdresField.il,
    AdresField.ilce,
    AdresField.mahalle,
    AdresField.cadde,
    AdresField.disKapi,
    AdresField.icKapi,
  ],
  IntegrationType.netsis => const [
    AdresField.il,
    AdresField.ilce,
    AdresField.adres,
    AdresField.postaKodu,
  ],
};

/// An address type of the API's fixed list.
@immutable
class AdresTipi {
  const AdresTipi(this.id, this.ad);

  final int id;
  final String ad;
}

/// An address of a Cari. Absent texts are empty strings.
@immutable
class CariAdres {
  const CariAdres({
    this.id,
    required this.cariId,
    required this.adresTipiId,
    this.adresTipi = '',
    this.il = '',
    this.ilce = '',
    this.mahalle = '',
    this.cadde = '',
    this.disKapi = '',
    this.icKapi = '',
    this.adres = '',
    this.postaKodu = '',
  });

  /// Null for a new address.
  final int? id;
  final int cariId;
  final int? adresTipiId;

  /// Name of the type, as the API returns it.
  final String adresTipi;
  final String il;
  final String ilce;
  final String mahalle;
  final String cadde;
  final String disKapi;
  final String icKapi;
  final String adres;
  final String postaKodu;

  /// Text of a text field; empty for [AdresField.adresTipi] / [AdresField.form].
  String valueOf(AdresField field) => switch (field) {
    AdresField.il => il,
    AdresField.ilce => ilce,
    AdresField.mahalle => mahalle,
    AdresField.cadde => cadde,
    AdresField.disKapi => disKapi,
    AdresField.icKapi => icKapi,
    AdresField.adres => adres,
    AdresField.postaKodu => postaKodu,
    AdresField.adresTipi || AdresField.form => '',
  };

  /// A copy with only the texts of [type]'s field set kept, trimmed.
  CariAdres forTenant(IntegrationType type) {
    final fields = adresFieldsFor(type);
    String keep(AdresField f) => fields.contains(f) ? valueOf(f).trim() : '';
    return CariAdres(
      id: id,
      cariId: cariId,
      adresTipiId: adresTipiId,
      adresTipi: adresTipi,
      il: keep(AdresField.il),
      ilce: keep(AdresField.ilce),
      mahalle: keep(AdresField.mahalle),
      cadde: keep(AdresField.cadde),
      disKapi: keep(AdresField.disKapi),
      icKapi: keep(AdresField.icKapi),
      adres: keep(AdresField.adres),
      postaKodu: keep(AdresField.postaKodu),
    );
  }
}

/// `GET /tml/cari/{id}/adresler`: the addresses and whether the Cari is
/// linked to Netsis (then they are read-only).
@immutable
class CariAdresList {
  const CariAdresList({required this.items, required this.netsisBagli});

  final List<CariAdres> items;
  final bool netsisBagli;
}

/// What is wrong with a field, before any text is chosen for it.
enum AdresIssue { required, tooLong, postaKodu, atLeastOne }

final _fiveDigits = RegExp(r'^\d{5}$');

/// The server's rules (`docs/api-contract.md` §6A.3.3), checked on the
/// client. Only the fields of [type]'s set count; the server checks again.
Map<AdresField, AdresIssue> validateAdres(
  CariAdres adres,
  IntegrationType type,
) {
  final issues = <AdresField, AdresIssue>{};
  if (adres.adresTipiId == null) {
    issues[AdresField.adresTipi] = AdresIssue.required;
  }

  final fields = adresFieldsFor(type);
  for (final field in fields) {
    if (field == AdresField.postaKodu) continue;
    if (adres.valueOf(field).trim().length > field.maxLength) {
      issues[field] = AdresIssue.tooLong;
    }
  }
  if (type == IntegrationType.netsis) {
    final postaKodu = adres.postaKodu.trim();
    if (postaKodu.isNotEmpty && !_fiveDigits.hasMatch(postaKodu)) {
      issues[AdresField.postaKodu] = AdresIssue.postaKodu;
    }
    if (adres.adres.trim().isEmpty) {
      issues[AdresField.adres] = AdresIssue.required;
    }
  } else if (fields.every((f) => adres.valueOf(f).trim().isEmpty)) {
    issues[AdresField.form] = AdresIssue.atLeastOne;
  }
  return issues;
}
