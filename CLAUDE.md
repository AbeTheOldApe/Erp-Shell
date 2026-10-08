# Flutter Web Taban Yazılım (Shell)

Bu dosya Claude Code için proje bağlamıdır. Kodlamaya başlamadan önce bunu ve `docs/` altındaki dosyaları oku. Bu dosyadaki kararlar **kesinleşmiştir**; bunlardan sapman gerekirse önce kullanıcıya sor.

## Proje özeti

Web üzerinde çalışan, Flutter ile yazılan bir **taban (shell) uygulama**. İş modülleri bu tabanın içine eklenecek.

- Solda, kullanıcı ve role göre atanmış modülleri **ağaç yapısında** gösteren bir menü var.
- Menüden bir modül seçilince modül, sağdaki içerik alanına **sekme (tab)** olarak açılır.
- Açık modüller sekme kulakçıklarıyla arasında gezilebilir.
- Uygulama **telefon, tablet ve bilgisayarda** kullanılabilir (responsive).
- Önce **backend olmadan, mock veriyle çalışan demo** yazılır. Backend sonra bağlanır.

## Dosya haritası

| Dosya | İçerik |
|---|---|
| `CLAUDE.md` | Bu dosya: özet, kararlar, mimari kurallar |
| `docs/ui-behaviors.md` | Ekran ve etkileşim davranışlarının ayrıntılı şartnamesi |
| `docs/menu-schema.md` | Mock modun sözleşmesi (login, menü JSON), yetki modeli, mock kullanıcılar |
| `docs/api-contract.md` | **Gerçek API'nin kesin sözleşmesi** (gerçek modda geçerli; Faz 4) |
| `docs/deployment.md` | Test sunucusuna paketleme ve dağıtım adımları (`tools/build-web.ps1`) |
| `docs/roadmap.md` | Fazlar ve kabul kriterleri. **Hangi işi yapacağını buradan al.** |

## Çalışma şekli

- `docs/roadmap.md`'deki fazları sırayla uygula. İstenmeyen fazın işini yapma.
- Belirsiz bir nokta varsa varsayım yapıp ilerleme, kısa bir soru sor.
- Bir faz bitince `docs/roadmap.md`'deki ilgili kutuları işaretle ve neyin test edildiğini yaz.
- Kod, yorum ve commit mesajları **İngilizce**; kullanıcıya görünen tüm metinler **Türkçe** ve `intl/ARB` dosyalarından gelir (koda gömme).

## Kesinleşmiş kararlar

| Konu | Karar |
|---|---|
| Platform | Flutter Web (öncelik). Kod mobil/masaüstüne taşınabilir kalsın ama hedef web. |
| Sekme kimliği | `tabKey = moduleKey`. **Bir modül en fazla bir sekmede açılır**; aynı modüle tekrar tıklanınca mevcut sekmeye geçilir. |
| Liste → detay | Sekme açmaz. **Modülün içinde** olur (breadcrumb ile). Derin link gerekirse query parametresi: `/m/siparis?id=1234`. |
| Sekme durumu | Sekmeler `IndexedStack` içinde canlı kalır; sekme değişince form verisi ve kaydırma konumu korunur. |
| Açılış ekranı | Açılışta **boş alan** (empty state: "Soldan bir modül seçin"). Ana Sayfa sekmesi yok. |
| Menü aç/kapa | Üst çubukta tek hamburger butonu. Ayrıntısı `docs/ui-behaviors.md`. |
| Responsive ölçütü | Cihaz türü değil **pencere genişliği** (Material 3 sınıfları). |
| Bölünmüş görünüm (split view) | **Kapsam dışı.** Ama `TabItem`'da `pinned` alanı olsun (Faz 1'de kullanılmaz). |
| Grid paketi | **TrinaGrid** (ücretsiz, MIT). `AppDataGrid` sarmalayıcısının arkasında kullanılır; doğrudan modüllerde kullanılmaz. |
| Boşta kalma | Boşta kalma süresine bağlı **zorunlu çıkış yok**. Teknik oturum sorunu (token yenilenemedi vb.) olursa "tekrar giriş yapın" uyarısı çıkar; giriş sonrası aynı sekmelere dönülür. |
| Favoriler, son kullanılanlar | **Faz 2** |
| Cockpit (ana panel) | **Faz 2** |
| Backend | Mock modda `USE_MOCK` bayrağı ile mock repository kullanılır. Gerçek API Faz 4'te bağlanır. |
| Gerçek mod sözleşmesi | Gerçek modda sözleşme `docs/api-contract.md`'dir; `menu-schema.md`'nin uç nokta, login/refresh gövdesi, `/me/menu` ve hata gövdesi tanımları gerçek mod için geçersizdir. Shell API'ye uyar; çeviri `Http*` repository'lerinde yapılır, UI değişmez. |
| Token depolama (gerçek mod) | Access token **yalnızca bellekte**; refresh token `httpOnly` cookie'de (JS erişemez). `auth.tokens` sessionStorage anahtarı gerçek modda kullanılmaz. |
| Menü (gerçek mod) | Menü ağacı **istemcide tanımlanır** ve `/me` → `Yetkiler.Pages` ile süzülür; `/me`'deki `Menu` kullanılmaz. |
| Modül yetkileri (gerçek mod) | `ModulePermissions`, modül kaydındaki sayfa kodu + buton kodu eşlemesinden üretilir (`api-contract.md` §5.2). |
| Favoriler (gerçek mod) | Şimdilik `localStorage`'da; API'ye taşınması sonraya kalır. |

## Teknoloji yığını

Paket sürümlerini `pub.dev`'den güncel kararlı sürüm olarak al ve uyumluluğu `flutter pub get` ile doğrula.

| Alan | Seçim |
|---|---|
| State | `flutter_riverpod` |
| Routing | `go_router`, `usePathStrategy()` (URL'de `#` yok) |
| HTTP | `dio` (interceptor: token ekleme, 401'de refresh) |
| Grid | `trina_grid` |
| Yerelleştirme | `flutter_localizations` + `intl` (ARB), varsayılan dil `tr` |
| Depolama | Kendi `KeyValueStore` arayüzümüz; web'de `localStorage` ve `sessionStorage` uygulamaları |
| Breakpoint | Ek paket yok, kendi `Breakpoints` sınıfımız (Material 3 sınıfları) |

Ek paket eklemeden önce kullanıcıya sor.

## Klasör yapısı

```
lib/
  main.dart
  app.dart                      # MaterialApp.router, tema, l10n
  core/
    config/                     # AppConfig (USE_MOCK, apiBaseUrl), config.json okuma
    network/                    # dio client, interceptor'lar
    auth/                       # AuthRepository (abstract), MockAuthRepository, HttpAuthRepository, session state
    storage/                    # KeyValueStore (abstract) + web implementasyonları
    router/                     # go_router yapılandırması, guard'lar
    theme/                      # ThemeData, renk tokenları
    l10n/                       # ARB dosyaları
    utils/                      # turkish_fold.dart, formatters.dart, breakpoints.dart
  shell/
    shell_page.dart             # responsive iskelet (menü + sekme çubuğu + içerik)
    side_menu/                  # ağaç, arama, ikon şeridi, flyout
    tabs/                       # TabsNotifier, TabBar (masaüstü/tablet), OpenModulesSheet (telefon), TabHost
    top_bar.dart
  modules/
    module_def.dart             # ModuleDef, ModuleContext
    registry.dart               # moduleKey -> ModuleDef haritası
    <modül_adı>/                # her modül kendi klasöründe
  shared/                       # ortak responsive widget'lar (Faz 3)
    app_data_grid/
    responsive_form/
    dialogs/
    states/                     # EmptyState, ErrorState, SkeletonLoader
  data/
    menu/                       # MenuRepository (abstract), Mock*, Http*
    mock/                       # mock JSON dosyaları (assets)
test/
web/
  index.html                    # bağlam menüsü ve beforeunload ayarları
```

## Mimari kurallar

1. **Mock yalnızca veri katmanında.** `AuthRepository` ve `MenuRepository` gibi soyut arayüzler olsun; `Mock*` ve `Http*` uygulamaları `--dart-define=USE_MOCK=true` ile seçilsin. UI mock'tan haberdar olmaz.
2. **Modül ekleme tek satırdır:** `registry.dart` içine `moduleKey -> ModuleDef` kaydı. Kabuk kodu modüle özel bilgi taşımaz.
3. **Modüller birbirini import etmez.** Modüller arası geçiş yalnızca `ctx.openModule(key, query: {...})` ile yapılır. Aynı modül zaten açıksa o sekmeye geçilir ve query iletilir.
4. **Yetki kontrolü UX içindir**, asıl kontrol API'dedir. Menüde yetkisiz modül gösterilmez; yetkisiz butonlar **gizlenir** (devre dışı bırakılmaz). Yetkisiz modüle URL ile girilirse "Yetkiniz yok" ekranı.
5. **Responsive kararlar tek yerden verilir:** `Breakpoints` sınıfı. Widget'larda `MediaQuery.size.width` ile doğrudan sabit sayı karşılaştırma.
6. **Modüller ortak widget'ları kullanır** (`shared/`). Grid, form, dialog ve durum ekranları her modülde yeniden yazılmaz.
7. **Modül yaşam döngüsü:** arka plandaki sekme `TickerMode` ile durdurulur; zamanlayıcılı yenilemeler yalnızca aktif sekmede çalışır.
8. **Sekme sınırı** cihaza göredir: telefon 5, tablet 10, masaüstü 15. Sınır aşılınca kullanıcıya uyarı verilir; **otomatik sekme kapatma yoktur** (veri kaybı riski).
9. **Türkçe metin arama/karşılaştırma** `turkishFold()` üzerinden yapılır (`İ/ı/I/i` farkı). Küçük harfe çevirmek için `toLowerCase()` doğrudan kullanılmaz.

## Kodlama kuralları

- Null safety, `flutter analyze` **sıfır uyarı**. `analysis_options.yaml` için `flutter_lints` kullan.
- Widget'lar küçük ve `const` mümkün olduğunca; build içinde ağır iş yok.
- State yönetimi yalnızca Riverpod; global mutable değişken yok.
- Renk, boşluk ve yazı stili `Theme`'den gelir; widget içinde sabit renk kodu yok.
- Dokunmatik hedefler en az 48x48 logical pixel.
- Metinler ARB'den gelir. Tarih `gg.aa.yyyy`, sayı `1.234,56` (`Formatters` sınıfı).
- Her yeni ortak widget için en az bir widget testi; sekme yönetimi ve menü filtreleme için birim testi.
- Hover'a bağımlı özellik yok: her hover/sağ tık işlevinin dokunmatik karşılığı olmalı (uzun bas vb.).

## Kapsam dışı (şimdilik)

- Bölünmüş görünüm / sekme grupları, sekmeleri sürükleyip yeniden düzenleme dışındaki docking
- Gerçek backend entegrasyonu (Faz 4'e kadar)
- Boşta kalma süresine bağlı otomatik çıkış
- Mobil/masaüstü paketleme (APK, Windows vb.)
- Çevrimdışı çalışma

## Komutlar

```bash
flutter pub get
flutter run -d chrome --dart-define=USE_MOCK=true
flutter analyze
flutter test
flutter build web --release --dart-define=USE_MOCK=true
```

Web sunucusu tüm yolları `index.html`'e yönlendirmelidir (`usePathStrategy` nedeniyle). Dağıtımda bunu unutma (IIS için `web.config` rewrite, Nginx için `try_files`).
