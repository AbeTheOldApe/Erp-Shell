import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kullanici/kullanici_module.dart';
import 'module_def.dart';
import 'musteri/musteri_module.dart';
import 'rapor_satis/rapor_satis_module.dart';
import 'rapor_stok/rapor_stok_module.dart';
import 'sevkiyat/sevkiyat_module.dart';
import 'siparis/siparis_module.dart';
import 'stok/stok_module.dart';

/// All modules known to the shell. Adding a module is one line here.
const Map<String, ModuleDef> moduleRegistry = {
  'siparis': ModuleDef('siparis', SiparisModule.new),
  'musteri': ModuleDef('musteri', MusteriModule.new),
  'stok': ModuleDef('stok', StokModule.new),
  'sevkiyat': ModuleDef('sevkiyat', SevkiyatModule.new),
  'rapor-satis': ModuleDef('rapor-satis', RaporSatisModule.new),
  'rapor-stok': ModuleDef('rapor-stok', RaporStokModule.new),
  'kullanici': ModuleDef('kullanici', KullaniciModule.new),
};

/// Registry lookup; overridable in tests.
final moduleRegistryProvider = Provider<Map<String, ModuleDef>>(
  (ref) => moduleRegistry,
);
