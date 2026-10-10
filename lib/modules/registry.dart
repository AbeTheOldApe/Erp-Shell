import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cari/cari_module.dart' deferred as cari;
import 'cockpit/cockpit_module.dart';
import 'kullanici/kullanici_module.dart' deferred as kullanici;
import 'module_def.dart';
import 'musteri/musteri_module.dart' deferred as musteri;
import 'rapor_satis/rapor_satis_module.dart' deferred as rapor_satis;
import 'rapor_stok/rapor_stok_module.dart' deferred as rapor_stok;
import 'sevkiyat/sevkiyat_module.dart' deferred as sevkiyat;
import 'siparis/siparis_module.dart' deferred as siparis;
import 'stok/stok_module.dart' deferred as stok;

/// All modules known to the shell. Adding a module is one entry here.
/// Business modules are deferred: their code is downloaded the first time
/// they are opened. The Cockpit is the landing page, so it is not.
final Map<String, ModuleDef> moduleRegistry = Map.unmodifiable({
  'cockpit': const ModuleDef('cockpit', CockpitModule.new, home: true),
  'siparis': ModuleDef(
    'siparis',
    (ctx) => siparis.SiparisModule(ctx),
    load: siparis.loadLibrary,
  ),
  'cari': ModuleDef(
    'cari',
    (ctx) => cari.CariModule(ctx),
    load: cari.loadLibrary,
    api: const ModuleApiPermissions(
      pageCode: 'CariMain',
      addButton: 'KAYDET',
      editButton: 'KAYDET',
      deleteButton: 'SIL',
    ),
    subApi: const {
      // The Adresler tab is granted apart from CariMain.
      'adresler': ModuleApiPermissions(
        pageCode: 'CariAdresler',
        addButton: 'KAYDET',
        editButton: 'KAYDET',
        deleteButton: 'SIL',
      ),
    },
  ),
  'musteri': ModuleDef(
    'musteri',
    (ctx) => musteri.MusteriModule(ctx),
    load: musteri.loadLibrary,
  ),
  'stok': ModuleDef(
    'stok',
    (ctx) => stok.StokModule(ctx),
    load: stok.loadLibrary,
  ),
  'sevkiyat': ModuleDef(
    'sevkiyat',
    (ctx) => sevkiyat.SevkiyatModule(ctx),
    load: sevkiyat.loadLibrary,
  ),
  'rapor-satis': ModuleDef(
    'rapor-satis',
    (ctx) => rapor_satis.RaporSatisModule(ctx),
    load: rapor_satis.loadLibrary,
  ),
  'rapor-stok': ModuleDef(
    'rapor-stok',
    (ctx) => rapor_stok.RaporStokModule(ctx),
    load: rapor_stok.loadLibrary,
  ),
  'kullanici': ModuleDef(
    'kullanici',
    (ctx) => kullanici.KullaniciModule(ctx),
    load: kullanici.loadLibrary,
  ),
});

/// Registry lookup; overridable in tests.
final moduleRegistryProvider = Provider<Map<String, ModuleDef>>(
  (ref) => moduleRegistry,
);

/// Key of the home (Cockpit) module, if one is registered.
final homeModuleKeyProvider = Provider<String?>((ref) {
  for (final def in ref.watch(moduleRegistryProvider).values) {
    if (def.home) return def.key;
  }
  return null;
});
