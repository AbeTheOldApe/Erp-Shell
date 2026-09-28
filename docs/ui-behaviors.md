# UI Davranış Şartnamesi

Bu dosya ekran ve etkileşim davranışlarını tanımlar. Faz numaraları `docs/roadmap.md` ile eşleşir. Faz belirtilmeyen maddeler **Faz 1**'dedir.

## 1. Responsive sınıflar

Ölçüt pencere genişliğidir. Tarayıcı penceresi küçülünce de doğru çalışmalıdır. `core/utils/breakpoints.dart` içinde tanımla:

| Sınıf | Genişlik (dp) | Kısaca |
|---|---|---|
| compact | < 600 | Telefon |
| medium | 600 – 1199 | Tablet |
| expanded | ≥ 1200 | Masaüstü |

Yön değişimi (dikey/yatay) ve pencere yeniden boyutlandırma sırasında **menü ve sekme durumu korunur**, yalnızca yerleşim değişir.

## 2. Kabuk yerleşimi

```
┌───────────────┬───────────────────────────────────────────┐
│  Üst çubuk: ☰  Aktif modül başlığı        🔍  🔔  👤      │
├───────────────┼───────────────────────────────────────────┤
│  Sol Menü     │ [Sipariş ✕] [Stok ✕] [Rapor ✕]  ← sekmeler │
│  (ağaç)       ├───────────────────────────────────────────┤
│  ▸ Satış      │                                           │
│    • Sipariş  │   Aktif modülün ekranı                    │
│  ▸ Depo       │   (diğer sekmeler canlı kalır)            │
└───────────────┴───────────────────────────────────────────┘
```

Üst çubuk: hamburger düğmesi, aktif modül başlığı, menü/modül arama (telefonda ikon), bildirim alanı (Faz 1'de yer tutucu), kullanıcı menüsü (profil yer tutucu, tema, dil, çıkış).

## 3. Sol menü

### 3.1 Aç/kapa davranışı (hamburger tek tuş)

| Sınıf | Varsayılan | Hamburger'e basınca |
|---|---|---|
| expanded | Genişletilmiş (~280px, içeriği iter) | İkon şeridine (~72px) daralır / geri genişler |
| medium | İkon şeridi (~72px) | Menü içeriğin **üstüne overlay** olarak genişler; dışına tıklayınca kapanır |
| compact | Gizli | Modal `Drawer` açılır; modül seçilince otomatik kapanır |

- Masaüstü/tablette son durum (genişletilmiş/daralmış) `localStorage`'da saklanır.
- **İkon şeridinde:** modüller ikon + tooltip olarak görünür. Grup ikonuna tıklayınca alt modüller **flyout** olarak açılır. Telefonda tooltip yerine uzun basma.

### 3.2 Ağaç

- En fazla **3 seviye** desteklenir.
- Gruplar açılıp kapanır; açık/kapalı durumu kullanıcı bazında `localStorage`'da saklanır.
- Yaprak düğüm modüle bağlıdır (`moduleKey`), grup düğüm bağlı değildir.
- Aktif modül ağaçta vurgulanır ve üst gruplar otomatik açılır.
- Düğüm yanında **rozet** (sayaç) alanı ayrılır: `badge` alanı doluysa gösterilir. Faz 1'de mock'ta boştur.
- Bir grubun altındaki hiçbir modülü kullanıcı göremiyorsa grup hiç gösterilmez.

### 3.3 Menü araması

- Menü başında arama kutusu. Yazdıkça ağaç filtrelenir, eşleşen dalların üst grupları açılır.
- Karşılaştırma `turkishFold()` ile yapılır: `İ ı I i` farkı yok sayılır, aksanlar ve büyük/küçük harf yok sayılır ("iş emri" = "IŞ EMRİ").
- İkon şeridi durumunda arama kutusu yerine arama ikonu bulunur ve tıklayınca menü genişler.

## 4. Sekmeler

### 4.1 Kurallar

- `tabKey = moduleKey`. Bir modül tek sekmede açılır; tekrar tıklanınca mevcut sekme aktif olur.
- Sekmeler `IndexedStack` ile canlı tutulur. Arka plandaki sekmelerde animasyonlar durdurulur (`TickerMode`).
- **Açılışta hiç sekme yoktur**, içerik alanında boş durum gösterilir ("Soldan bir modül seçin"). Son sekme kapatılınca da aynı boş durum görünür.
- `TabItem` alanları: `tabKey`, `title`, `moduleKey`, `pinned` (varsayılan `false`, Faz 2'de Cockpit için), `isDirty`.
- Sabit (`pinned`) sekmeler kapatılamaz ve her zaman en solda durur. Faz 1'de kullanılmaz, ama model ve sıralama mantığı bunu desteklemelidir.

### 4.2 Sekme sınırı

| Sınıf | Sınır |
|---|---|
| compact | 5 |
| medium | 10 |
| expanded | 15 |

Sınır aşılınca yeni modül açılmaz ve "Açık modül sınırına ulaştınız, birini kapatın" uyarısı gösterilir. **Otomatik kapatma yok.**

### 4.3 Masaüstü ve tablet: sekme çubuğu

- Yatay sekme çubuğu; taşınca kaydırma okları ve tüm sekmeleri listeleyen açılır liste düğmesi. Aktif sekme her zaman görünür alana kaydırılır.
- Her sekmede başlık, kaydedilmemiş değişiklik göstergesi (nokta) ve kapatma (✕) düğmesi.
- Orta tuş ile kapatma (yalnızca fare).
- Sağ tık (tablette uzun basma) menüsü: **Yenile**, **Kapat**, **Diğerlerini kapat**, **Sağdakileri kapat**, **Tümünü kapat**. Sabit sekmeler bu işlemlerden etkilenmez.
- Sürükleyerek sıralama: **yalnızca expanded** sınıfta (`ReorderableListView`).
- Sekme "Yenile": modülü sıfırdan kurar (kaydedilmemiş değişiklik varsa önce onay).

### 4.4 Telefon: açık modüller

- Sekme çubuğu yoktur. Üst çubukta aktif modül adı ve yanında **açık modül sayısı rozetli** bir düğme bulunur.
- Düğme, açık modülleri listeleyen bir **bottom sheet** açar: modüle dokununca geçiş, ✕ ile kapatma. Kapatma işlemleri aynı `isDirty` uyarısından geçer.

### 4.5 Kaydedilmemiş değişiklik (`isDirty`)

- Modül `ctx.setDirty(true/false)` ile bildirir.
- Şu durumlarda uyarı diyaloğu çıkar: sekme kapatma, "diğerlerini/tümünü kapat", sekme yenileme, çıkış yapma.
- Tarayıcı sekmesi kapatılırken/yenilenirken dirty sekme varsa `beforeunload` uyarısı verilir.

### 4.6 URL ve tarayıcı geçmişi

- Aktif sekme URL ile eşleşir: `/m/:moduleKey` (+ query). Tarayıcı geri tuşu bir önceki aktif sekmeye döner.
- URL'e doğrudan girilirse (F5, paylaşılan link): modül yetkisi varsa sekme açılır; yoksa "Yetkiniz yok" ekranı; bilinmeyen `moduleKey` ise "Modül bulunamadı" ekranı.

### 4.7 Sekme kalıcılığı (Faz 2)

- F5 sonrası açık sekmelerin **listesi ve aktif sekme** geri yüklenir. Form içeriği **geri yüklenmez**.
- Kayıt `sessionStorage`'da tutulur (tarayıcı sekmesi bazında, iki tarayıcı sekmesi birbirini bozmasın). Menü tercihi, tema, dil gibi ayarlar `localStorage`'dadır.

### 4.8 Klavye kısayolları

Tarayıcı `Ctrl+W`, `Ctrl+Tab` gibi kısayolları yakaladığı için web'de bunlar **kullanılmaz**.

| Kısayol | İşlev | Faz |
|---|---|---|
| `Alt+W` | Aktif sekmeyi kapat | 1 |
| `Alt+←` / `Alt+→` | Önceki / sonraki sekme | 1 |
| `Alt+1` … `Alt+9` | N. sekmeye git | 1 |
| `Ctrl+S` | Kaydet (modül tanımlarsa) | 3 |
| `Esc` | Diyalog/flyout kapat | 1 |
| `Ctrl+K` | Komut paleti (modül arama ve açma) | 2 |

Kısayol listesi yardım diyaloğunda gösterilir.

## 5. Modül sözleşmesi

Her modül şunları alır/sağlar (`modules/module_def.dart`):

```dart
class ModuleDef {
  final String key;
  final Widget Function(ModuleContext ctx) builder;
  const ModuleDef(this.key, this.builder);
}

abstract class ModuleContext {
  String get moduleKey;
  ModulePermissions get permissions;         // canView/canAdd/canEdit/canDelete
  Map<String, String> get query;             // URL query parametreleri
  Stream<Map<String, String>> get queryChanges; // aynı modül tekrar açılınca yeni query
  void setDirty(bool value);
  void openModule(String moduleKey, {Map<String, String>? query});
  void requestRefresh();
}
```

- Modül başlığı ve ikonu menü verisinden gelir; modül kendi başlığını bilmez.
- Modülün içindeki liste → detay geçişi modülün **kendi iç gezintisidir** (iç `Navigator` veya iç state). Breadcrumb ile gösterilir: "Siparişler › SP-1234". Dar ekranda ortadaki halkalar açılır menüye katlanır, **son eleman her zaman görünür**.

## 6. Ortak bileşenler (Faz 3)

`shared/` altında; modüller bunları kullanmak zorundadır.

| Bileşen | Davranış |
|---|---|
| `ResponsiveScaffold` | Modül sayfası çerçevesi: başlık, aksiyon çubuğu, içerik; dar ekranda aksiyonlar taşma menüsüne |
| `ResponsiveForm` | expanded 3 kolon, medium 2 kolon, compact 1 kolon; alan altı doğrulama mesajı; kaydet'te ilk hatalı alana odaklanma |
| `AppDataGrid` | `trina_grid` sarmalayıcısı. expanded/medium: tablo. compact: **kart listesi** (her sütun için "kartta göster" işareti). Sunucu taraflı sayfalama/sıralama/filtre sözleşmesi (`page`, `pageSize`, `sort`, `filter`). Ctrl+C ile seçimi sekmeyle ayrılmış olarak panoya kopyalar. Sütun sırası/genişlik/görünürlük kullanıcı bazında saklanır. Dışa aktarma: CSV |
| Filtre alanı | expanded/medium: grid üstünde satır; compact: "Filtre" düğmesiyle bottom sheet |
| `AdaptiveDialog` | compact'ta tam ekran, diğerlerinde ortalı diyalog |
| `EmptyState`, `ErrorState`, `SkeletonLoader` | Boş / hata / yükleniyor durumları için tek tip |
| Bildirimler | Başarı: kısa snackbar. Hata: kalıcı banner. Kritik onay: diyalog. Geri dönüşsüz işlemde (silme vb.) tek tip onay diyaloğu |

Form etkileşimi: `Enter` ile sonraki alana geçiş, `Esc` diyalog kapatma, `Ctrl+S` kaydet.

## 7. Sağ tık ve dokunmatik

- Uygulama sağ tık menüsünü kendisi yönetir. `web/index.html` içinde:

```html
<script>
  document.addEventListener('contextmenu', function (e) {
    if (!e.ctrlKey) e.preventDefault();   // Ctrl+sağ tık: tarayıcı menüsü (debug için)
  });
</script>
```

- Her sağ tık menüsünün dokunmatik karşılığı **uzun basma**dır.
- Salt okunur metin alanlarında `SelectionArea` kullanılır; kullanıcılar değer kopyalayabilmelidir.

## 8. Oturum

- **Boşta kalma nedeniyle zorunlu çıkış yoktur.**
- Token süresi dolarsa refresh denenir. Refresh başarısız olursa (teknik sorun) engelleyici bir diyalog çıkar: **"Oturumunuz sona erdi, lütfen tekrar giriş yapın."** Giriş yapılınca kullanıcı **aynı sekmelere ve aynı ekrana** döner. Dirty sekme varsa girişten önce kullanıcıya belirtilir (veri kaybolmasın).
- Bir tarayıcı sekmesinde çıkış yapılınca diğer tarayıcı sekmeleri de `storage` olayı ile giriş ekranına düşer (Faz 2).
- Menü oturum başında bir kez çekilir. Kullanıcı menüsünde "Menüyü yenile" komutu bulunur. Açık modülde API 403 dönerse sekmede "Yetkiniz değişmiş olabilir" uyarısı gösterilir.

## 9. Kişiselleştirme, dil ve erişilebilirlik

- **Tema:** açık, koyu, sistem. Kullanıcı menüsünden; tek `ThemeData` kaynağı.
- **Dil:** varsayılan Türkçe, altyapı `intl/ARB` ile çok dile hazır.
- **Biçimler:** tarih `gg.aa.yyyy`, sayı `1.234,56`; hepsi `Formatters` sınıfından.
- **Yazı boyutu:** sistem ölçeğine saygı, üst sınırlı (taşma yapmasın).
- **Erişilebilirlik:** odak halkası görünür, menü ve sekmede `Semantics` etiketleri, kontrast WCAG AA.

## 10. Web'e özgü notlar

- `usePathStrategy()`; sunucuda tüm yollar `index.html`'e yönlendirilir.
- İlk yükleme için `index.html`'de basit bir yükleme göstergesi.
- Ortam ayarları (`apiBaseUrl`, `useMock`) `--dart-define` ve/veya çalışma zamanında `config.json` ile gelir (yeniden derlemeden ortam değişimi).
- Modüller `deferred as` ile tembel yüklenir (Faz 3).
