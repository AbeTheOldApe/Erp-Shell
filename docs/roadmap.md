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

- [x] `ResponsiveScaffold`, `ResponsiveForm`, `AdaptiveDialog`
- [x] `AppDataGrid` (TrinaGrid sarmalayıcısı): tablo/kart listesi geçişi, sayfalama-sıralama-filtre sözleşmesi, Ctrl+C kopyalama, sütun tercihleri, CSV dışa aktarma
- [x] Filtre alanı (satır / bottom sheet)
- [x] `EmptyState`, `ErrorState`, `SkeletonLoader`, bildirim standartları, onay diyaloğu
- [x] Modül içi breadcrumb bileşeni
- [x] `siparis` modülünü liste → detay örneğine dönüştür (grid + breadcrumb + form + `isDirty` + yetkiye göre buton gizleme)
- [x] Modüllerin `deferred as` ile tembel yüklenmesi
- [x] Widget testleri (grid geçişi, form kolonları)

**Kabul:** `siparis` modülü üç ekran sınıfında da kullanılabilir; yetkisiz kullanıcıda ekle/sil butonları görünmez; dirty formda sekme kapatınca uyarı çıkar.

**Kararlar ve uygulama notları (Faz 3):**
- **Liste sorgu sözleşmesi:** kullanıcı kararıyla JSON gövdeli `POST /<kaynak>/query` (`{page, pageSize, sort[], filters[]}` → `{items, total}`). Ayrıntı ve `Siparişler` API'si `docs/menu-schema.md` §5'te. `GridQuery`/`GridFilter`/`GridSort` bu sözleşmeyi birebir taşır (`toJson`/`fromJson`); `LocalGridDataSource` aynı sözleşmeyi bellekte uygular ve mock repository'lerin temelini oluşturur.
- **Sipariş detayı:** kullanıcı kararıyla başlık formu + kalemler grid'i (liste ekranıyla aynı sekmede, breadcrumb ile). Kalemler bağımsız bir API çağrısı yapmaz; `AppDataGrid`'in yerel veri kaynağı üzerinde çalışır. `tutar` sunucuda (mock'ta da) kalemlerden hesaplanır.
- **`depo` kullanıcısı** artık Siparişler'i salt okunur görüyor (yeni Faz 3 yetki örneği): "Yeni", "Kaydet", "Sil" gizli, form salt okunur. `satis` kullanıcısında silme yok.
- **AppDataGrid ↔ TrinaGrid:** sıralama sunucuya bırakılır (`setSortOnlyEvent(true)`); TrinaGrid yalnızca o anki sayfayı render eder. Sütun sırası/genişlik/görünürlük `ui.grid.<userId>.<moduleKey>.<gridId>` altında `localStorage`'a kaydedilir (yarım saniye gecikmeli). Ctrl+C TrinaGrid'in kendi kopyalama kısayolundan gelir. Telefonda tablo yerine kart listesi; sıralama üstteki bir menüden yapılır (sütun başlığı yok).
- **CSV dışa aktarma:** `;` ayraç, UTF-8 BOM, `\r\n`, ekrandaki biçimle aynı değerler (Excel/Türkçe ayar için). Tarayıcıda gerçek indirme ile doğrulandı (bayt düzeyinde BOM kontrolü dahil).
- **Tembel yükleme:** Cockpit dışındaki 7 modül `deferred as` ile ayrı JS parçalarına derleniyor (derlemede 18 parça oluştu). Yükleme süresince `SkeletonLoader`, hata olursa `ErrorState` + tekrar dene gösterilir.
- **Breadcrumb:** normalde yalnızca son eleman kısalır; satır gerçekten sığmayacaksa (uzun başlıklar + dar ekran/büyük yazı) üst düzeyler de kısalabilir, en dar durumda tek "…" menüsüne katlanır.
- **`ResponsiveForm`** `maxColumns` alır; diyalog içi formlar (kalem ekleme) pencereden bağımsız olarak 2 sütunu geçmez.

**Test edilenler (Faz 3):** `flutter test` → 91 test geçti, `flutter analyze` temiz.
- `test/shared/shared_widgets_test.dart`: `ResponsiveForm` 3/2/1 sütun ve tam genişlik alanı, ilk hatalı alana odaklanma; `Breadcrumb` sığınca tam liste, dar ekranda katlanma ("…" menüsü açılır), iki uzun elemanda taşma olmadan kısalma, iki kısa elemanda kısaltma yapılmaması; `ResponsiveScaffold` geniş ekranda etiketli düğmeler, telefonda birincil ikon + taşma menüsü; `AdaptiveDialog` telefonda tam ekran / diğerlerinde ortalı (ResponsiveForm ile intrinsic-genişlik hatası olmadığı doğrulandı); onay diyaloğu; `EmptyState`/`ErrorState`/`SkeletonLoader`; `FilterBar` satır halinde ve bottom sheet'te.
- `test/shared/app_data_grid_test.dart`: geniş ekranda tablo / telefonda kart listesi ve biçimlendirilmiş değerler; sayfalama isteği; telefon sıralama menüsü; boş durum; `LocalGridDataSource` Türkçe filtre + sıralama + sayfalama, tarih aralığı; `GridQuery` JSON gidiş-dönüşü; CSV (`;`, BOM, tırnaklama, biçim); `GridPreferences` kaydet/yükle ve sıra uygulama; `Formatters.tryParseNumber`/`editable`.
- `test/modules/siparis_test.dart`: mock API sözleşmeye uygun filtre/sıralama/sayfalama ve 401; `yonetici` tam yetkili liste→detay; `depo` salt okunur (Kabul); `satis` silme yok; dirty formda sekme kapatma ve breadcrumb ile geri dönme onay ister (Kabul); derin link `?id=` ve bilinmeyen id; kaydettikten sonra tarayıcı geri tuşuyla listeye dönünce liste yenilenir (mutasyon testiyle doğrulandı); yeni sipariş doğrulama + kalem ekleme + kaydetme; telefonda kart listesi.
- Chrome'da elle denendi: liste/filtre/sıralama/sayfalama, CSV indirme (bayt düzeyinde BOM), çift tıklamayla detay açma, kalem düzenleme diyaloğu (2 sütun), Ctrl+S ile kaydetme, derin link + giriş sonrası geri dönüş, tarayıcı geri tuşuyla listeye dönüş, telefonda (400 px, iframe) breadcrumb ve form. Tembel yüklenen modülün gerçek derlemede ayrı JS parçasına ayrıldığı doğrulandı.
- Bulunan ve düzeltilen iki hata: (1) breadcrumb iki elemanlı ve dar ekranda taşıyordu — üst düzeyler de gerektiğinde kısalacak şekilde değiştirildi; (2) kaydedip tarayıcı geri tuşuyla listeye dönüldüğünde liste yenilenmiyordu (yalnızca uygulama içi "geri" yenileniyordu) — artık her çıkışta yenileniyor.
- Denenemeyen: TrinaGrid'in kendi Ctrl+C kopyalama kısayolu (pano izni gerektirdiği için otomasyonla doğrulanamadı, yalnızca kod/kütüphane incelemesiyle doğrulandı).

## Faz 4: Gerçek API

Gerçek modun sözleşmesi `docs/api-contract.md`'dir (`menu-schema.md`'deki ilgili maddeler gerçek mod için geçersiz). Shell API'ye uyar; çeviri `Http*` repository'lerindedir, UI değişmez. Mock modu eskisi gibi çalışmaya devam etmelidir.

### 4.1 Hazırlık: dokümanlar, config.json, geliştirme proxy'si

- [x] `CLAUDE.md` dosya haritası ve kesinleşmiş kararlar, `menu-schema.md` uyarı notu, bu yol haritası
- [x] `web/config.json` (`{ "apiBaseUrl": "/api/v1", "useMock": false }`); `AppConfig` bunu çalışma zamanında okur, `--dart-define` önceliklidir
- [x] `tools/dev-proxy/` (Node, kendi `package.json`'ı): `localhost:8080`; `/api/*` → `https://test.opticode.com.tr` (Host/Origin yeniden yazılır, `Set-Cookie` aynen), diğer her şey → `localhost:5000` (Flutter web-server)

**Kabul:** Mock komutları (`--dart-define=USE_MOCK=true`) bozulmadan çalışır; `flutter analyze`/`flutter test` temiz; proxy üzerinden `GET /api/v1/health` test API'sine ulaşır.

### 4.2 API istemcisi ve oturum

- [x] `dio` istemcisi, zarf ayrıştırma (`IsSuccessful`/`MessageCode`/`Data`) ve hata eşleme (HTTP durumu + `MessageCode` → tipli hata)
- [x] Auth interceptor: bellekte access token, `Authorization: Bearer`, `X-Requested-With: OptiCodeApp`, 401'de single-flight refresh + isteği bir kez tekrar, Web Locks (`opt-refresh`)
- [x] `HttpAuthRepository` (login, refresh, logout, `/me`); `auth.tokens` kullanılmaz
- [x] Açılışta sessiz refresh (F5 dahil): başarılıysa giriş ekranı gösterilmez
- [x] Refresh başarısızsa mevcut oturum sona erme diyaloğu; sekmeler ve durumları korunur; logout `auth.logoutSignal` ile diğer sekmelere

**Kabul:** Gerçek kullanıcıyla giriş; F5'te sessiz oturum; eşzamanlı 401'lerde tek refresh isteği; refresh başarısızken diyalog ve girişten sonra aynı sekmeler. Birim testleri: zarf/hata eşleme, single-flight, tekrar deneme bir kez.

**Test edilenler (4.2):** `flutter analyze` temiz, `flutter test` 115 test geçti, `flutter build web --release --dart-define=USE_MOCK=false` derlendi. `test/core/api_session_test.dart` (sahte HTTP adaptörüyle): zarf (200 + `IsSuccessful=false` istisna değil, 4xx/5xx eşleme, 500'de genel metin, bilinmeyen kodda sunucu mesajı); `/auth/*`'ta `X-Requested-With` var, `Authorization` yok; iki eşzamanlı 401 → tek refresh; istek bir kez tekrarlanır, ikinci 401'de tekrar yok; refresh başarısız → `expired`, kullanıcı korunur; access token hiçbir `KeyValueStore`'a yazılmaz, sessionStorage'daki eski kayıt okunmaz; açılışta refresh başarısız → login (kullanıcı seçici yok), başarılı → `/me` ve kabuk; router guard (`/loading`, `from`).
**Düzeltme (yönlendirme):** `from` yalnızca uygulama içi, `/login` ve `/loading` dışı bir yol ise kullanılır, aksi halde ana sayfa; oturum açıkken `/login`'e (F5 + sessiz refresh dahil) gelen kullanıcı ana sayfaya gider. Çıkışta adres `/login` (from yok).
**Notlar:** Gerçek API'ye karşı tarayıcıda denendi. Web Locks (`navigator.locks`) kodu derlenir ama VM testlerinde kilitsiz kısmı çalışır. Proaktif yenileme yapılmadı (opsiyoneldi). 403 "Yetkiniz değişmiş olabilir" davranışı 4.3'e taşındı. Gerçek modda menü geçici olarak boş (yalnızca Cockpit sekmesi, 4.3'e kadar); gerçek modda favoriler şimdilik `localStorage`'daki `LocalFavoritesRepository` ile (kabuğun çökmemesi için gerekliydi). `web` paketi eklendi (onaylı).

### 4.3 Menü ve yetkiler

- [ ] İstemci menü tanımı (`moduleKey` + `pageCode`, ARB başlıkları)
- [ ] `HttpMenuRepository`: `/me` → `Yetkiler.Pages` ile süzme, boş grup gizleme, Cockpit yetkisiz; `badge` her zaman `null`
- [ ] `ModulePermissions` eşlemesi (sayfa + buton kodu)
- [ ] Gerçek modda favoriler `localStorage`'da
- [ ] Açık modülde API 403 dönerse sekmede "Yetkiniz değişmiş olabilir" uyarısı (4.2'den taşındı; ilk gerçek modül isteği 4.4'te geldiği için orada da doğrulanır)

**Kabul:** Gerçek modda yalnızca yetkili sayfalar menüde görünür (mock modüller görünmez); buton yetkisi yoksa ilgili butonlar gizlenir. Menü süzme ve yetki eşleme birim testleri.

### 4.4 Cari modülü

- [ ] Liste (`Arama`, rol ve pasif filtreleri, sayfalama; sunucu sıralaması yok, sütun sıralaması kapalı)
- [ ] Detay formu, kaydet/sil; `NetsisBagliMi` olan cari salt okunur (Kaydet/Sil gizli)
- [ ] `MessageCode` eşlemeleri (1002, 1004, 1005, 1201–1205) ARB'ye
- [ ] `CariRepository`: mock ve http uygulamaları

**Kabul:** Gerçek API ile cari listele/ara/filtrele, ekle, güncelle, sil; alan hataları ilgili alanda görünür. Repository ve eşleme testleri.

### 4.5 Test sunucusuna dağıtım ve uçtan uca doğrulama

- [ ] `flutter build web --release --no-web-resources-cdn --dart-define=USE_MOCK=false`; fontlar pubspec'e gömülü
- [ ] `robocopy <build\web> C:\OptiCodeWeb\test\web /MIR /XF web.config`
- [ ] `https://test.opticode.com.tr` üzerinde uçtan uca: giriş, F5, yenileme, çıkış, Cari akışı; konsolda CSP ihlali yok

**Kabul:** Test ortamında demo akışının tamamı çalışır; UI kodunda değişiklik gerekmemiştir.

**Kararlar (Faz 4):** Token depolama yeniden değerlendirmesi karara bağlandı: access token bellekte, refresh token `httpOnly` cookie (bkz. `CLAUDE.md`).

## Kapsam dışı / gelecek fikirleri

- Bölünmüş görünüm ve sekme grupları (talep gelirse ayrıca değerlendirilecek)
- Boşta kalma süresine bağlı otomatik çıkış
- Çevrimdışı çalışma
