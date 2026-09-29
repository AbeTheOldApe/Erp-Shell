# Yol Haritası

Fazları sırayla uygula. Bir fazı bitirince kutuları işaretle. Ayrıntılı davranışlar için `docs/ui-behaviors.md`, veri sözleşmesi için `docs/menu-schema.md`.

## Faz 0: İskelet

- [x] `flutter create` (web hedefi), klasör yapısı `CLAUDE.md`'deki gibi
- [x] Paketler: `flutter_riverpod`, `go_router`, `dio`, `trina_grid`, `intl`, `flutter_localizations`
- [x] `flutter_lints`, `analysis_options.yaml`
- [x] `AppConfig` (`USE_MOCK`, `apiBaseUrl`), `KeyValueStore` arayüzü ve web uygulamaları
- [x] `Breakpoints`, `turkishFold()`, `Formatters`
- [x] Tema (açık/koyu/sistem), ARB altyapısı (`tr`)
- [x] `web/index.html`: bağlam menüsü betiği, yükleme göstergesi, `beforeunload` köprüsü

**Kabul:** `flutter run -d chrome --dart-define=USE_MOCK=true` boş bir uygulama açar; `flutter analyze` temiz.

**Test edilenler (Faz 0):** `flutter analyze` sıfır sorun; `flutter build web --release --dart-define=USE_MOCK=true` başarılı (Flutter 3.44.3). `turkishFold`, `Breakpoints`, `Formatters` birim testleri (`test/core/utils_test.dart`). Notlar: mock JSON'lar `assets/mock/` altında (`menu-schema.md` ile uyumlu); ARB'ye `en` de eklendi (dil menüsü için); `beforeunload` köprüsünün Dart tarafı (`core/utils/unload_guard.dart`) hazır, bağlanması Faz 2'de.

## Faz 1: Kabuk ve demo temel

- [x] Mock login ekranı (3 kullanıcı), `AuthRepository`/`MenuRepository` arayüzleri ve `Mock*` uygulamaları
- [x] Oturum state'i, `go_router` guard'ı (girişsiz kullanıcı login'e)
- [x] `/me/menu` mock JSON'u ve ağaç modeli, yetkiye göre boş grup gizleme
- [x] Responsive kabuk: expanded/medium/compact yerleşimleri (`docs/ui-behaviors.md` §2–3)
- [x] Tek hamburger ile menü aç/kapa: ikon şeridi, flyout, overlay, drawer; tercih `localStorage`'da
- [x] Menü ağacı: aç/kapa, aktif vurgu, rozet alanı, arama (`turkishFold`)
- [x] Sekme yönetimi: `TabsNotifier` (`open`, `close`, `activate`, `closeOthers`, `closeRight`, `closeAll`), `TabItem` (`pinned` dahil)
- [x] Masaüstü/tablet sekme çubuğu; telefon "açık modüller" bottom sheet'i
- [x] `IndexedStack` + `TickerMode` ile canlı sekmeler
- [x] Sekme sınırı (5/10/15) ve uyarısı
- [x] URL eşleşmesi `/m/:moduleKey`, geri tuşu, "Yetkiniz yok" ve "Modül bulunamadı" ekranları
- [x] Açılış boş durumu ("Soldan bir modül seçin")
- [x] Kısayollar: `Alt+W`, `Alt+←/→`, `Alt+1..9`, `Esc`
- [x] `ModuleDef`, `ModuleContext`, `registry.dart`; 7 boş mock modül
- [x] Oturum sona erme diyaloğu ("tekrar giriş yapın") ve girişten sonra aynı sekmelere dönüş; mock'ta "Oturum süresini doldur" düğmesi
- [x] Kullanıcı menüsü: tema, dil, çıkış, "Menüyü yenile"
- [x] Testler: sekme yönetimi birim testleri, menü filtreleme/arama birim testi, responsive yerleşim widget testleri

**Kabul:**
1. Üç kullanıcı ile giriş yapınca her birinin yetkisine göre farklı menü görünür.
2. Aynı modüle iki kez tıklamak ikinci sekme açmaz.
3. Tarayıcı penceresi 1400px → 800px → 400px'e küçültülünce yerleşim uygun sınıfa geçer, açık sekmeler kaybolmaz.
4. "Oturumu doldur" düğmesi tüm sekmelerin yerinde kaldığı bir giriş diyaloğu çıkarır; girişten sonra kullanıcı aynı yerde devam eder.

**Test edilenler (Faz 1):** `flutter test` → 44 test geçti, `flutter analyze` temiz.
- `test/shell/tabs_notifier_test.dart`: aç/tekrar aç (ikinci sekme yok), query güncelleme, sınır (otomatik kapatma yok), kapatma sonrası komşu aktif, `closeOthers/closeRight/closeAll`, `pinned` sıralama ve korunma, yeniden sıralama, dirty/yenile.
- `test/data/menu_tree_test.dart`: sıralama, boş grup gizleme (her seviyede), 3 seviye sınırı, `turkishFold` ile arama ("iş emri" = "IŞ EMRİ"), 3 mock kullanıcının menüleri (Kabul 1; `depo`'da Sevkiyat rozeti "3").
- `test/shell/shell_layout_test.dart`: 1400/800/400 px yerleşimleri; aynı modüle iki tıklama tek sekme (Kabul 2); 1400 → 800 → 400 px'te sekmeler ve form metni korunuyor (Kabul 3); kullanıcıya göre menü; menü araması; girişsiz kullanıcı login'e.
- `test/shell/session_expiry_test.dart`: "Oturum süresini doldur" → 401 → refresh başarısız → diyalog; sekmeler yerinde; girişten sonra form metni duruyor (Kabul 4).
- Chrome'da elle denendi (`flutter run -d web-server --release`): giriş yönlendirmesi (`/login?from=`), 3 kullanıcının menüleri, menü araması, rozet, ikon şeridi + flyout (3. seviye), tablet overlay, telefon "açık modüller" sheet'i, sekme çubuğu ve sağ tık menüsü, geri tuşu, "Yetkiniz yok" / "Modül bulunamadı", kısayollar (`Alt+←/→`, `Alt+1..9`, `Alt+W`; tarayıcının Alt+← "geri" işlemi engelleniyor), oturum sona erme akışı, F5 sonrası oturumun korunması; konsolda hata yok. Tablet/telefon genişlikleri iframe ile denendi (pencere boyutlandırılamadı).
- Tarayıcı denemesinde bulunan hata düzeltildi: kısayollar, odaklı alan arka plandaki sekmeyle birlikte kaldırılınca çalışmıyordu (`CallbackShortcuts` → `HardwareKeyboard` işleyicisi); regresyon testi eklendi.
- Denenemeyenler: orta tuşla sekme kapatma ve sürükleyerek sıralama (tarayıcı otomasyonu desteklemiyor).
- Mock menüye 3. seviye örneği ve 7. modül için "Raporlar › Depo Raporları › Stok Raporu" (`rapor-stok`) eklendi.

## Faz 2: Zenginleştirme

- [x] **Cockpit**: sabit (`pinned`) ilk sekme olarak ana panel; açılış boş durumu yerine Cockpit gelir
- [x] **Favoriler**: menüde yıldız, menü başında "Favoriler" bölümü (kullanıcı bazlı)
- [x] **Son kullanılanlar**: son 5 modül
- [x] **Komut paleti** (`Ctrl+K`, telefonda arama ikonu): modül arama ve açma
- [x] Sekme kalıcılığı: F5 sonrası açık sekmeler ve aktif sekme (`sessionStorage`)
- [x] Çıkış yapılınca diğer tarayıcı sekmelerinin de girişe düşmesi (`storage` olayı)
- [x] Modülde `isDirty` ve sekme/çıkış/`beforeunload` uyarıları (altyapı Faz 1'de, uyarı akışı burada tamamlanır)
- [x] Yardım diyaloğu: kısayol listesi

**Kabul:** F5 sonrası aynı sekmeler geri gelir; Cockpit kapatılamaz; favoriler ve son kullanılanlar oturumlar arasında korunur.

**Kararlar ve uygulama notları (Faz 2):**
- **Cockpit** şimdilik yer tutucu bir modüldür (`modules/cockpit`). İçeriği ana modüller eklendikçe safha safha gelecek; yetkilendirmesi o zaman belirlenecek (şu an herkese görüntüleme yetkisiyle açılır). Kabuk Cockpit'i adıyla bilmez: `registry.dart`'ta `ModuleDef(..., home: true)` olan modül ana sekmedir, `/` adresinde gösterilir, menüde yer almaz. Ana modül kaydı yoksa eski boş durum ("Soldan bir modül seçin") görünür.
- **Favoriler** ileride API'ye taşınacak: `FavoritesRepository` arayüzü + `MockFavoritesRepository`; önerilen uç noktalar `docs/menu-schema.md` §1'de. Mock, "sunucu" tarafını `localStorage`'da tutar ve 401/oturum akışına katılır.
- **Son kullanılanlar** komut paletinde (boş aramada) gösterilir; aktif sekme değiştikçe güncellenir, Cockpit ve o an açık olan modül listelenmez.
- Favori ekleyip çıkarmak "Favoriler" bölümünün boyunu değiştirip ağacı kaydırdığı için bölüm boyutunu animasyonla değiştirir; favoriden çıkarma snackbar'daki "Geri al" ile geri alınabilir (yanlış yıldıza basılırsa).
- **Komut paleti** üst çubuktaki arama ikonuyla da açılır (tüm genişliklerde); telefonda tam ekran. Ok tuşlarıyla seçim, Enter ile açma; alt başlıkta grup yolu ("Raporlar › Depo Raporları").
- **Kaydedilmemiş değişiklik** onayı: sekme kapatma (✕, `Alt+W`, orta tuş, bottom sheet), "Diğerlerini/Sağdakileri/Tümünü kapat", "Yenile", çıkış (kullanıcı menüsü ve oturum sona erme diyaloğu). `beforeunload` bayrağı sekmelerin dirty durumuna bağlandı.
- Sekme kaydı çıkışta silinir; kaydedilen sekmeler, menüde yetkisi kalmayan modülleri atlayarak geri yüklenir ve sınırı aşsa da kapatılmaz.

**Test edilenler (Faz 2):** `flutter test` → 54 test geçti, `flutter analyze` temiz.
- `test/shell/phase2_test.dart`: Cockpit kapatılamaz (`Alt+W`, "Tümünü kapat", bağlam menüsünde "Kapat" yok); F5 sonrası sekmeler geri gelir (Kabul; geri yükleme kapatılınca test başarısız olduğu doğrulandı); favori ekle/çıkar, "Favoriler" bölümü ve oturumlar arası kalıcılık (Kabul); son kullanılanların oturumlar arası kalıcılığı ve paletteki bölüm (Kabul); `Ctrl+K` → arama → Enter; dirty sekmeyi kapatırken onay (Vazgeç / Değişiklikleri at); başka tarayıcı sekmesinden çıkış sinyali; `TabsPersistence` ve son kullanılanlar (5 sınırı) birim testleri.
- Chrome'da elle denendi: Cockpit açılışı, `Ctrl+K` (tarayıcının kendi Ctrl+K'sı engelleniyor), palette ok tuşu + Enter, favori yıldızı ve bölümü, `sessionStorage`/`localStorage` kayıtları, `beforeunload` bayrağının dirty durumuyla açılıp kapanması, F5 sonrası sekmelerin ve favorilerin geri gelmesi, iki tarayıcı sekmesi arasında çıkışın yayılması.
- Denenemeyen: gerçek `beforeunload` uyarı penceresi (tarayıcı otomasyonunu kilitlediği için tetiklenmedi; yalnızca bayrak doğrulandı).

## Faz 3: Ortak bileşenler ve örnek modül

- [ ] `ResponsiveScaffold`, `ResponsiveForm`, `AdaptiveDialog`
- [ ] `AppDataGrid` (TrinaGrid sarmalayıcısı): tablo/kart listesi geçişi, sayfalama-sıralama-filtre sözleşmesi, Ctrl+C kopyalama, sütun tercihleri, CSV dışa aktarma
- [ ] Filtre alanı (satır / bottom sheet)
- [ ] `EmptyState`, `ErrorState`, `SkeletonLoader`, bildirim standartları, onay diyaloğu
- [ ] Modül içi breadcrumb bileşeni
- [ ] `siparis` modülünü liste → detay örneğine dönüştür (grid + breadcrumb + form + `isDirty` + yetkiye göre buton gizleme)
- [ ] Modüllerin `deferred as` ile tembel yüklenmesi
- [ ] Widget testleri (grid geçişi, form kolonları)

**Kabul:** `siparis` modülü üç ekran sınıfında da kullanılabilir; yetkisiz kullanıcıda ekle/sil butonları görünmez; dirty formda sekme kapatınca uyarı çıkar.

## Faz 4: Gerçek API

- [ ] `HttpAuthRepository`, `HttpMenuRepository` (`docs/menu-schema.md` sözleşmesine uygun)
- [ ] `dio` interceptor: token ekleme, 401'de refresh, başarısızsa oturum sona erme diyaloğu
- [ ] `config.json` ile çalışma zamanı ortam ayarı
- [ ] Token depolama yaklaşımının yeniden değerlendirilmesi (güvenlik gözden geçirmesi)
- [ ] Dağıtım notu: sunucuda `index.html` yönlendirmesi

**Kabul:** `USE_MOCK=false` ile demo akışlarının tamamı gerçek API ile çalışır; UI kodunda değişiklik gerekmez.

## Kapsam dışı / gelecek fikirleri

- Bölünmüş görünüm ve sekme grupları (talep gelirse ayrıca değerlendirilecek)
- Boşta kalma süresine bağlı otomatik çıkış
- Çevrimdışı çalışma
