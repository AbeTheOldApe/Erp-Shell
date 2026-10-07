# Gerçek API Sözleşmesi (OptiCode App API)

Bu doküman, shell'in **gerçek modda** (`USE_MOCK=false`) konuştuğu API'yi tanımlar. API ayrı bir repoda
(`opticode-app-api`) geliştirilir ve test ortamında uçtan uca doğrulanmıştır. Buradaki sözleşme
**kesindir**; shell API'ye uyum sağlar, API shell'e göre değiştirilmez.

`docs/menu-schema.md`'deki uç nokta, login/refresh gövdesi, `/me/menu` ve hata gövdesi tanımları
API yazılmadan önce **varsayılmıştı**. Gerçek mod için bu doküman geçerlidir. Mock repository'ler
eski biçimde kalabilir; çeviri `Http*` repository'lerinde yapılır ve UI kodu değişmez.

## 1. Genel

| Konu | Değer |
|---|---|
| Taban adres | Göreli: `/api/v1`. Shell ve API **aynı origin**'den sunulur; build'e domain gömülmez |
| Test ortamı | `https://test.opticode.com.tr` (statik dosyalar `/`, API `/api/v1`) |
| Canlı ortam | `https://app.opticode.com.tr` (henüz devrede değil) |
| CORS | **Yok.** API yalnızca kendi origin'inden gelen istekleri kabul eder |
| Alan adları | **PascalCase**, API ile SP arasında çeviri yok (`CariUnvani`, `KullaniciAdi`). Shell'deki Dart modelleri kendi adlarını kullanabilir; çeviri `Http*` katmanında |
| Tarih/saat | ISO 8601 |
| Dil | Sunucu mesajları (`Message`) Türkçedir |

## 2. Cevap zarfı

Her cevap (iş kuralı reddi dahil) aynı zarfla döner:

```json
{ "IsSuccessful": true, "Message": "İşlem başarılı.", "MessageCode": 200, "Data": { } }
```

| Durum | HTTP | `MessageCode` | `IsSuccessful` |
|---|---|---|---|
| Başarılı | 200 | 200 | true |
| **İş kuralı reddi** (kayıt bulunamadı, tekrar eden kod vb.) | **200** | 1001–1999 | false |
| Gövde/parametre okunamıyor | 400 | 2001 | false |
| Alan validasyonu | 422 | 2002 | false |
| Oturum yok/geçersiz/süresi dolmuş | 401 | 2003 | false |
| Yetki yok, Origin/X-Requested-With hatalı | 403 | 2003 | false |
| Tanımsız route | 404 | 2004 | false |
| Rate limit | 429 | 2005 | false |
| Beklenmeyen sunucu hatası | 500 | 2999 | false |

Önemli: **HTTP 200 her zaman başarı demek değildir.** `Http*` repository'leri `IsSuccessful`'a bakar.
İş kuralı reddi (1xxx) kullanıcıya gösterilecek bir sonuçtur, istisna değildir.

Ortak kodlar: `1001` geçersiz JSON, `1002` zorunlu alan eksik, `1003` geçersiz değer, `1004` kayıt
bulunamadı (başka tenant'ın kaydı dahil), `1005` kayıt zaten o durumda. Modüle özgü kodlar ilgili
bölümde.

Gösterim kuralı: bilinen `MessageCode`'lar ARB metinlerine eşlenir; eşleme yoksa sunucunun `Message`
metni gösterilir. 500'de kullanıcıya genel bir hata metni gösterilir, ayrıntı yoktur.

## 3. Başlıklar

| Başlık | Ne zaman |
|---|---|
| `Authorization: Bearer <AccessToken>` | `/auth/*` dışındaki bütün korumalı istekler |
| `X-Requested-With: OptiCodeApp` | **Bütün `/auth/*` isteklerinde zorunlu**; yoksa 403. Diğer isteklerde de gönderilebilir |
| `Content-Type: application/json; charset=utf-8` | Gövdeli isteklerde |
| `Origin` | Tarayıcı kendisi ekler; `/auth/*`'ta varsa sitenin kendi origin'i olmak zorunda |

## 4. Oturum

### 4.1 Model

| Parça | Değer |
|---|---|
| Access token | JWT, 15 dk (`ExpiresIn: 900`). Login/refresh cevabının gövdesinde gelir. **Yalnızca bellekte tutulur**; `localStorage`/`sessionStorage`'a yazılmaz |
| Refresh token | `__Secure-opt_rt` cookie'si: `HttpOnly; Secure; SameSite=Strict; Path=/api/v1/auth`, 7 gün kayan, 30 gün mutlak. **JavaScript erişemez**; tarayıcı `/api/v1/auth/*` isteklerine kendisi ekler |
| Token içeriği | Shell token'ı çözmez, yetki kararı vermez. Kullanıcı ve yetki bilgisi `/me`'den alınır |

`docs/menu-schema.md` §4'teki `auth.tokens` (sessionStorage) anahtarı gerçek modda **kullanılmaz**.

### 4.2 Uç noktalar

**`POST /api/v1/auth/login`**

```json
// istek
{ "KullaniciAdi": "esin", "Sifre": "..." }
// 200
{ "IsSuccessful": true, "Message": "Giriş başarılı.", "MessageCode": 200,
  "Data": { "AccessToken": "eyJ...", "ExpiresIn": 900, "TokenType": "Bearer" } }
```

- `KullaniciAdi` kullanıcı adı **veya** e-posta olabilir. `Sifre` kırpılmaz, büyük/küçük harfe duyarlıdır.
- Başarılıysa cevapta refresh cookie'si (`Set-Cookie`) gelir.
- Hatalı bilgi: 401/2003, `Message`: "Kullanıcı adı veya şifre hatalı." (kullanıcı adı mı şifre mi belli edilmez).
- Hesap kilitliyse (5 hatalı deneme → 15 dk): 401/2003, kilit mesajı. Bu `Message` olduğu gibi gösterilir.
- Rate limit: aynı IP + kullanıcı adı için dakikada 5 istek → 429/2005.

**`POST /api/v1/auth/refresh`**: gövde yok. Cookie'yi tarayıcı gönderir.

- 200: `Data` login ile aynı (`AccessToken`, `ExpiresIn`, `TokenType`). Yeni cookie gelebilir de gelmeyebilir
  de (aynı anda yapılan iki refresh'in ikincisinde cookie yazılmaz); shell bununla ilgilenmez.
- 401/2003: oturum bitti (cookie yok, süresi dolmuş, iptal edilmiş ya da tekrar kullanım tespit edildi).

**`POST /api/v1/auth/logout`**: gövde yok. Her durumda 200; refresh token iptal edilir, cookie silinir.

**`GET /api/v1/me`** (Bearer)

```json
{ "IsSuccessful": true, "MessageCode": 200, "Message": "İşlem başarılı.",
  "Data": {
    "Kullanici": { "AppUserId": 13, "TenantId": 2, "UserName": "esin", "FullName": "...", "Email": "..." },
    "Ortam": "Test",
    "Menu": [],
    "Yetkiler": {
      "Pages": ["CariMain"],
      "Buttons": { "CariMain": ["KAYDET", "SIL"] }
    }
  } }
```

- `Menu` her zaman boştur ve **kullanılmaz**; menü ağacı istemcide tanımlanır (bkz. §5).
- `Yetkiler` yalnızca görünürlük içindir. Asıl kontrol API'dedir; yetkisiz istek 403 alır.

### 4.3 İstemci davranışı (zorunlu)

1. **Açılışta sessiz refresh:** Sayfa yüklendiğinde (F5 dahil) bellekte token yoktur. Shell önce
   `POST /auth/refresh` dener. Başarılıysa `/me` çağrılır ve kullanıcı giriş ekranını görmeden devam eder.
   Başarısızsa giriş ekranı gösterilir.
2. **401 yönetimi:** `/auth/*` dışındaki bir istek 401 alırsa **tek bir** refresh denenir ve istek **bir kez**
   tekrarlanır. Refresh de başarısız olursa mevcut "Oturumunuz sona erdi, lütfen tekrar giriş yapın"
   diyaloğu gösterilir; sekmeler ve durumları korunur.
3. **Single-flight:** Aynı anda birden fazla 401 gelirse yalnızca bir refresh isteği gider, diğerleri onun
   sonucunu bekler.
4. **Tarayıcı sekmeleri arası:** Refresh, Web Locks API ile (`navigator.locks.request('opt-refresh', ...)`)
   tek sekmeye indirgenir. Desteklenmeyen tarayıcıda sunucudaki 30 sn'lik tolerans devreye girer.
5. **Proaktif yenileme** (opsiyonel): `ExpiresIn` bitmeden yaklaşık 60 sn önce arka planda refresh.
6. **Logout:** `POST /auth/logout`, ardından bellekteki token ve kullanıcı durumu temizlenir. Diğer tarayıcı
   sekmelerine mevcut `auth.logoutSignal` mekanizmasıyla iletilir.
7. **403:** Açık bir modülde 403 gelirse mevcut "Yetkiniz değişmiş olabilir" davranışı uygulanır.

## 5. Menü ve yetkiler

### 5.1 Menü ağacı istemcide

Menü yapısı (gruplar, başlıklar, ikonlar, sıralama) shell'de tanımlanır. Her yaprak bir `moduleKey`
ve bir API **sayfa koduna** (`pageCode`) bağlanır. Gerçek modda kullanıcının gördüğü ağaç, bu tanımın
`/me` → `Yetkiler.Pages` ile süzülmüş halidir:

- `pageCode`'u `Pages` içinde olmayan yaprak görünmez.
- Yaprağı kalmayan grup gizlenir (mevcut kural).
- Cockpit (`home: true`) yetki gerektirmez.

`HttpMenuRepository` bu süzmeyi yapıp shell'in mevcut menü modelini (`menu-schema.md` §1'deki ağaç
yapısı) üretir; UI değişmez. `badge` gerçek modda şimdilik her zaman `null`.

Mock modüller (`siparis`, `musteri` vb.) için API'de sayfa kodu yok; gerçek modda görünmezler. Mock
modda eskisi gibi çalışırlar.

### 5.2 Modül yetkileri

API yetkisi "sayfa kodu + buton kodları" biçimindedir. Shell'in `ModulePermissions`'ı
(`canView/canAdd/canEdit/canDelete`) modül kaydındaki bir eşlemeyle üretilir:

| Bayrak | Kural |
|---|---|
| `canView` | `pageCode` `Pages` içinde |
| `canAdd`, `canEdit`, `canDelete` | Modülün tanımladığı buton koduna göre: `Buttons[pageCode]` o kodu içeriyorsa `true` |

### 5.3 Tanımlı modüller

| moduleKey | Menü yeri | pageCode | canAdd | canEdit | canDelete |
|---|---|---|---|---|---|
| `cari` | Tanımlar › Cariler | `CariMain` | `KAYDET` | `KAYDET` | `SIL` |

Menü başlıkları ve grup adı ARB'den gelir; kullanıcı değiştirmek isterse yalnızca ARB ve menü tanımı
güncellenir.

## 6. Cari API'si

Tenant ayrımı sunucuda yapılır: kullanıcı yalnızca kendi tenant'ının carilerini görür ve değiştirir.
Başka tenant'ın bir carisine erişim `1004` (bulunamadı) döner.

### 6.1 `GET /api/v1/tml/cari` — liste (yetki: `CariMain`)

Query parametreleri:

| Parametre | Tip | Kural |
|---|---|---|
| `Page` | int | ≥ 1, varsayılan 1 |
| `PageSize` | int | 1–200, varsayılan 50 |
| `Arama` | string | ≤ 100, boş olabilir. `CariKodu`, `CariUnvani`, `CariKisaUnvani`, `Cari`, `VergiNo`, `TcKimlikNo` içinde arar |
| `CarininMusteriRoluVarMi` | bool | Opsiyonel; yoksa filtre yok |
| `CarininUrunTedarikcisiRoluVarMi` | bool | Opsiyonel |
| `CarininHizmetTedarikcisiRoluVarMi` | bool | Opsiyonel |
| `PasifGoster` | bool | Varsayılan `false` → yalnızca `Status = 'Valid'` |

Cevap:

```json
{ "IsSuccessful": true, "MessageCode": 200, "Message": "İşlem başarılı.",
  "Data": {
    "Items": [ {
      "CariId": 5563, "CariKodu": "", "Cari": "...", "CariUnvani": "...", "CariKisaUnvani": "...",
      "TelefonNo": "...", "EPostaAdresi": "...", "VergiDairesi": "", "VergiNo": "...", "TcKimlikNo": "",
      "CarininMusteriRoluVarMi": false, "CarininUrunTedarikcisiRoluVarMi": false,
      "CarininHizmetTedarikcisiRoluVarMi": false, "Status": "Valid", "NetsisBagliMi": false } ],
    "TotalCount": 175, "Page": 1, "PageSize": 50 } }
```

- **Sunucu taraflı sıralama yoktur**; sıra sunucunun belirlediği sabit sıradır. Bu modülün grid'inde
  sütun başlığıyla sıralama kapalıdır.
- `AppDataGrid`'in `GridQuery` sözleşmesi bu uç noktaya `CariHttpRepository` içinde çevrilir:
  `page/pageSize` doğrudan; tek bir arama kutusu `Arama`'ya; rol ve pasif filtreleri ilgili parametrelere.
  Desteklenmeyen filtre/sıralama gönderilmez.

### 6.2 `GET /api/v1/tml/cari/{CariId}` — tekil (yetki: `CariMain`)

`Data`: listedeki alanlar + formdaki bütün alanlar (`WebAdresi`, `FaksNo`, `OtomatikCariEkstreYollansinMi`
vb.). Yoksa ya da başka tenant'a aitse `IsSuccessful: false`, `1004`. Alan listesini ilk entegrasyonda
gerçek cevaptan doğrula.

### 6.3 `POST /api/v1/tml/cari` — kaydet (yetki: `CariMain` + `KAYDET`)

`CariId` yok ya da `0` → yeni kayıt; dolu → güncelleme.

| Alan | Kural |
|---|---|
| `CariId` | int ≥ 0, opsiyonel |
| `CariUnvani` | **zorunlu**, ≤ 100 |
| `Cari` | ≤ 100 |
| `CariKodu` | ≤ 15, opsiyonel; doluysa tenant içinde benzersiz |
| `CariKisaUnvani` | ≤ 50 |
| `WebAdresi` | ≤ 60 |
| `EPostaAdresi` | ≤ 255 |
| `TelefonNo`, `FaksNo` | ≤ 20 |
| `VergiDairesi` | ≤ 50 |
| `VergiNo` | ≤ 15 |
| `TcKimlikNo` | ≤ 11 |
| `CarininMusteriRoluVarMi`, `CarininUrunTedarikcisiRoluVarMi`, `CarininHizmetTedarikcisiRoluVarMi`, `OtomatikCariEkstreYollansinMi` | bool, opsiyonel |

Bilinmeyen alanlar sunucuda atılır. Başarı: `Data: { "CariId": 5564 }`.

Metin kolonları Türkçe kod sayfasındadır: bu kod sayfasında olmayan karakterler (Kiril, emoji vb.)
`?` olarak kaydedilir. İstemci şimdilik bunu engellemez.

### 6.4 `DELETE /api/v1/tml/cari/{CariId}` — sil (yetki: `CariMain` + `SIL`)

Soft delete. Başarıda `IsSuccessful: true`.

### 6.5 Cari'ye özgü kodlar

| Kod | Anlam | Shell davranışı |
|---|---|---|
| 1002 | Zorunlu alan eksik | İlgili alan hatası |
| 1004 | Kayıt bulunamadı | "Kayıt bulunamadı" ekranı / listeye dön |
| 1005 | Kayıt zaten silinmiş | Bilgi mesajı, listeyi yenile |
| 1201 | Cari kodu bu tenant'ta zaten kullanılıyor | `CariKodu` alanında hata |
| 1202 | Vergi no / TC kimlik no zaten kullanılıyor | `VergiNo`/`TcKimlikNo` alanında hata |
| 1203 | Netsis'e bağlı cari değiştirilemez/silinemez | Bilgi mesajı (normalde form zaten salt okunur) |
| 1204 | Bekleyen Netsis isteği var | Bilgi mesajı |
| 1205 | Finansal hareket nedeniyle silinemez | Bilgi mesajı |

`NetsisBagliMi: true` olan cari formda **salt okunur** açılır; Kaydet ve Sil gizlenir.

## 7. Geliştirme ve dağıtım

### 7.1 Yerel geliştirme: proxy

Aynı origin şartı nedeniyle shell `localhost`'ta doğrudan test API'sine bağlanamaz. `tools/dev-proxy/`
altındaki Node aracı tek bir adresten hem shell'i hem API'yi sunar:

- `http://localhost:8080/api/*` → `https://test.opticode.com.tr/api/*`. `Host` başlığı
  `test.opticode.com.tr` yapılır; `Origin` varsa `https://test.opticode.com.tr` olarak yeniden yazılır.
  `Set-Cookie` olduğu gibi iletilir (Chrome `localhost`'u güvenli bağlam saydığı için `Secure` cookie'yi kabul eder).
- Diğer bütün yollar → `flutter run -d web-server --web-port 5000` ile çalışan Flutter geliştirme sunucusu.
- Yalnızca geliştirme içindir; canlı dağıtımın parçası değildir.

### 7.2 Çalışma zamanı ayarı

`web/config.json` (build'e kopyalanır): `{ "apiBaseUrl": "/api/v1", "useMock": false }`.
`--dart-define` değeri verilmişse önceliklidir.

### 7.3 Test sunucusuna dağıtım

- Build: `flutter build web --release --no-web-resources-cdn --dart-define=USE_MOCK=false`
  (`--no-web-resources-cdn`: CanvasKit gstatic'ten değil build'den yüklenir; sunucunun CSP'si dış kaynağa izin vermez).
- Fontlar pubspec'e gömülür; tarayıcının Google Fonts'tan font indirmesine güvenilmez.
- Hedef: sunucuda `C:\OptiCodeWeb\test\web`. Kopyalarken sunucudaki `web.config` **korunur**
  (`robocopy <build\web> C:\OptiCodeWeb\test\web /MIR /XF web.config`). Shell'in kendi `web.config`'i yoktur;
  IIS kuralları (SPA yönlendirmesi, `/api` proxy, güvenlik başlıkları) sunucuda hazırdır.
- `index.html` ve `flutter_bootstrap.js` IIS tarafından `no-cache` ile sunulur.
- CSP şu an `Report-Only`; tarayıcı konsolunda CSP ihlali olmamalıdır.
