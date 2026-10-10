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

Bir modülün bir parçası (ör. sekme) kendi sayfa koduyla ayrıca yetkilendirilebilir; bu, modül kaydındaki
alt yetki tanımıyla (`ModuleDef.subApi`) yapılır ve ana sayfa kodundan bağımsızdır:

| moduleKey | Alt yetki | pageCode | canAdd | canEdit | canDelete |
|---|---|---|---|---|---|
| `cari` | `adresler` (Adresler sekmesi) | `CariAdresler` | `KAYDET` | `KAYDET` | `SIL` |

Mock modda `Yetkiler` yoktur; alt yetki modülün menüden gelen yetkisini izler.

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

`Data`: listedeki alanlar + formdaki bütün alanlar. Yoksa ya da başka tenant'a aitse `IsSuccessful: false`,
`1004`.

`GET /tml/cari/5563` gerçek cevabının alan adları (test ortamında doğrulandı; Cari formunun hepsi bu
alanlarla doldurulur, eksik alan boş/`false` kabul edilir, bilinmeyen alan yok sayılır):

| Alan | Tip |
|---|---|
| `CariId` | int |
| `CariKodu`, `Cari`, `CariUnvani`, `CariKisaUnvani` | string |
| `WebAdresi`, `EPostaAdresi`, `TelefonNo`, `FaksNo` | string |
| `VergiDairesi`, `VergiNo`, `TcKimlikNo` | string |
| `CarininMusteriRoluVarMi`, `CarininUrunTedarikcisiRoluVarMi`, `CarininHizmetTedarikcisiRoluVarMi`, `OtomatikCariEkstreYollansinMi` | bool |
| `Status` (`'Valid'` = aktif) | string |
| `NetsisBagliMi` | bool |

Boş `CariKodu`, `VergiNo` ve `TcKimlikNo` (`""`) birden çok kayıtta kabul edilir; `1201`/`1202` yalnızca
dolu değerlerde üretilir.

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

## 6A. Cari adresleri API'si

Bu bölüm §6'daki Cari sözleşmesinin devamıdır; zarf, hata kodları, oturum ve başlık kuralları orada tanımlıdır.
Alan adları PascalCase'tir. Tenant ayrımı sunucuda yapılır: kullanıcı yalnızca kendi tenant'ının carilerinin adreslerini görür ve
değiştirir; başka tenant'a ait bir cari ya da adres `1004` döner.

### 6A.1 Tenant'ın entegrasyon türü ve alan kümesi

`GET /api/v1/me` cevabına `Data.Tenant` eklenmiştir:

```json
"Tenant": { "EntegrasyonTuru": "Yok" }
```

| EntegrasyonTuru | Anlamı | Adres formunda gösterilen alanlar |
|---|---|---|
| `Yok` | Muhasebe/ERP entegrasyonu yok (ör. Cagkan) | `Il`, `Ilce`, `MahalleKoyMezraMevkii`, `CaddeSokakBucakMahalle`, `DisKapi`, `IcKapi` |
| `Netsis` | Netsis entegrasyonu var | `Il`, `Ilce`, `Adres`, `PostaKodu` |

Shell bu değeri oturumla birlikte tutar ve adres formunu ona göre kurar. Alan kümesine ait olmayan bir alan gönderilirse sunucu onu
**yok sayar** (yeni kayıtta NULL kalır, güncellemede mevcut değer korunur); istemci yine de yalnızca kendi kümesinin alanlarını gönderir.
Değer bilinmiyorsa ya da tanınmıyorsa `Yok` kümesi kullanılır.

### 6A.2 Sayfa ve buton kodları

| Sayfa kodu | Butonlar | Kullanım |
|---|---|---|
| `CariAdresler` | `KAYDET`, `SIL` | Adres listesi, okuma: sayfa kodu yeter. Kaydet: `KAYDET`. Sil: `SIL` |

`CariAdresler`, `CariMain`'den bağımsız verilir: kullanıcıda `CariMain` olup `CariAdresler` yoksa adresler sekmesi görünmez.
`canView` = `Pages` içinde `CariAdresler`; `canAdd` ve `canEdit` = `Buttons.CariAdresler` içinde `KAYDET`; `canDelete` = `SIL`.

### 6A.3 Uç noktalar

#### 6A.3.1 `GET /api/v1/tml/cari/{CariId}/adresler` — carinin adresleri (yetki: `CariAdresler`)

```json
{ "IsSuccessful": true, "MessageCode": 200, "Message": "İşlem başarılı.",
  "Data": {
    "Items": [ {
      "CariAdresId": 5828, "CariId": 5574, "AdresTipiId": 1, "AdresTipi": "…",
      "Il": "Izmir", "Ilce": "Bornova", "MahalleKoyMezraMevkii": "Test Mah.", "CaddeSokakBucakMahalle": null,
      "DisKapi": null, "IcKapi": null, "Adres": null, "PostaKodu": null } ],
    "NetsisBagliMi": false } }
```

- Sayfalama yok; bir carinin adres sayısı küçüktür.
- Yalnızca silinmemiş ve geçerli (`Status = 'Valid'`) adresler gelir. Sıra `CariAdresId` artan.
- `NetsisBagliMi: true` ise carinin adresleri **salt okunur**dur (aşağıda `1203`).
- Cari yoksa ya da başka tenant'a aitse: `IsSuccessful: false`, `1004`.

#### 6A.3.2 `GET /api/v1/tml/cari-adres/{CariAdresId}` — tek adres (yetki: `CariAdresler`)

`Data`: §6A.3.1'deki bir öğenin alanları + `NetsisBagliMi`. Yoksa ya da başka tenant'a aitse `1004`.

#### 6A.3.3 `POST /api/v1/tml/cari-adres` — kaydet (yetki: `CariAdresler` + `KAYDET`)

`CariAdresId` yok ya da `0` → yeni adres; dolu → güncelleme (`CariId` değiştirilemez, `1003`).

| Alan | Kural |
|---|---|
| `CariAdresId` | int ≥ 0, opsiyonel |
| `CariId` | **zorunlu**, int > 0 |
| `AdresTipiId` | **zorunlu**; §6A.3.5'teki listede bulunmalı (`1003`) |
| `Il`, `Ilce` | ≤ 25 |
| `MahalleKoyMezraMevkii`, `CaddeSokakBucakMahalle` | ≤ 50 |
| `DisKapi`, `IcKapi` | ≤ 25 |
| `Adres` | ≤ 255 |
| `PostaKodu` | ≤ 5; doluysa tam 5 rakam (`1003`) |

Kümeye göre ek kurallar:

- Tenant'ın alan kümesinden **en az bir alan** dolu olmalı (boşluk sayılmaz), yoksa `1002` ("En az bir adres alanı doldurulmalıdır.").
- `Netsis` kümesinde `Adres` zorunludur (`1002`, "Adres zorunludur.").
- Metinler sunucuda kırpılır; boş metin NULL olur.

Başarı: `Data: { "CariAdresId": 5828 }`.

#### 6A.3.4 `DELETE /api/v1/tml/cari-adres/{CariAdresId}` — sil (yetki: `CariAdresler` + `SIL`)

Soft delete. Başarıda `IsSuccessful: true`, `Data: { "CariAdresId": … }`. Zaten silinmişse `1005`; yoksa `1004`.

#### 6A.3.5 `GET /api/v1/tml/adres-tipleri` — adres tipi listesi (yetki: `CariAdresler`)

```json
{ "IsSuccessful": true, "MessageCode": 200, "Message": "İşlem başarılı.",
  "Data": { "Items": [ { "AdresTipiId": 1, "AdresTipi": "…" }, { "AdresTipiId": 2, "AdresTipi": "…" } ] } }
```

Adres tipleri bütün tenant'larda ortak bir sabit listedir (tenant'a göre değişmez). İstemci listeyi oturum başına bir kez çeker ve
form açılırken seçenek olarak kullanır; adları kodda sabitlemez.

### 6A.4 Cari adreslerine özgü kodlar

| Kod | Anlam | Shell davranışı |
|---|---|---|
| 1002 | Zorunlu alan eksik (adres tipi, adres alanı, Netsis'te `Adres`) | Mesaj formda gösterilir; `Adres` zorunluluğu ilgili alanda |
| 1003 | Geçersiz değer (adres tipi, posta kodu, `CariId` değiştirme) | Posta kodu hatası `PostaKodu` alanında; diğerleri form başında |
| 1004 | Cari ya da adres bulunamadı | "Kayıt bulunamadı", listeyi yenile |
| 1005 | Adres zaten silinmiş | Bilgi mesajı, listeyi yenile |
| 1203 | Netsis'e bağlı carinin adresi değiştirilemez/silinemez | Bilgi mesajı; normalde arayüz zaten salt okunurdur |

### 6A.5 Salt okunur durum

`NetsisBagliMi: true` olan carinin adres listesinde Ekle, Düzenle ve Sil **gizlenir** (devre dışı bırakılmaz), üstte bilgi bandı gösterilir
(carinin kendi formundaki bantla aynı metin). Yetki olmasa bile (`KAYDET`/`SIL` yok) aynı düğmeler gizlenir.

## 6B. Cari belgeleri API'si

Bu bölüm §6 (Cari) ve §6A (Cari Adresleri) bölümlerinin devamıdır; zarf, hata kodları, oturum ve başlık kuralları orada
tanımlıdır. Alan adları PascalCase'tir. Tenant ayrımı sunucuda yapılır: kullanıcı yalnızca kendi tenant'ının carilerinin belgelerini görür ve
değiştirir; başka tenant'a ait bir cari ya da belge `1004` döner.

### 6B.1 Kavram

Bir **cari belgesi** bir başlık ve bir ya da daha fazla **kalemden** oluşur (belge–kalem). Cagkan'da belgelerin tamamı "Açılış" tipindedir ve
belge başına tek kalem vardır; yine de bir belgede birden fazla kalem serbesttir. Belgenin toplamı kalemlerin `Tutar` toplamıdır (sunucu listede
`ToplamTutar` olarak döner; belge kaydında toplam gönderilmez).

### 6B.2 Sayfa ve buton kodları

| Sayfa kodu | Butonlar | Kullanım |
|---|---|---|
| `CariBelgeler` | `KAYDET`, `SIL` | Liste ve okuma: sayfa kodu yeter. Kaydet: `KAYDET`. Sil: `SIL` |

`CariBelgeler`, `CariMain` ve `CariAdresler`'den bağımsız verilir. `canView` = `Pages` içinde `CariBelgeler`; `canAdd` ve `canEdit` =
`Buttons.CariBelgeler` içinde `KAYDET`; `canDelete` = `SIL`.

Netsis'e bağlı cari kuralı (`1203`) belgelere **uygulanmaz**: Netsis senkronu carinin kendi alanlarını ezer, belgelerini değil. Bu yüzden belge
ekranında Netsis salt okunur durumu ve bilgi bandı yoktur; düğmeler yalnızca yetkiye bağlıdır.

### 6B.3 Uç noktalar

#### 6B.3.1 `GET /api/v1/fi/cari-belge-secenekleri` — sabit listeler (yetki: `CariBelgeler`)

Tek çağrıda belge formunun bütün seçenekleri. Ortak sabit listelerdir (tenant'a göre değişmez); istemci oturum başına bir kez çeker ve
kullanıcı değişince ya da çıkışta temizler. Adları kodda sabitlemez.

```json
{ "IsSuccessful": true, "MessageCode": 200, "Message": "İşlem başarılı.",
  "Data": {
    "BelgeTipleri":   [ { "CariBelgeTipiId": 1, "CariBelgeTipi": "Satış Faturası", "Sign": 1 } ],
    "DovizBirimleri": [ { "DovizBirimiId": 1, "DovizBirimi": "TRL", "DovizBirimiTanimi": "TÜRK LİRASI", "DovizSimgesi": "₺" } ],
    "Birimler":       [ { "BirimId": 1, "Birim": "Adet", "BirimKodu": "AD" } ],
    "Vadeler":        [ { "OdemeVadeId": 1, "OdemeVade": "Peşin", "OdemeVadeGunSayisi": 0 } ] } }
```

- `BelgeTipleri` yalnızca geçerli (aktif) tipleri içerir. `Sign` (+1 / −1 / 0) tipin cari bakiyeye etkisidir; Hareket Dökümü ve Yaşlandırma
  ekranlarının dayanağıdır, bu ekranda yalnızca saklanır, işlenmez.
- Her liste `…Id` sırasıyla gelir.

#### 6B.3.2 `GET /api/v1/fi/cari/{CariId}/belgeler` — carinin belgeleri (yetki: `CariBelgeler`)

Query: `Page` (≥ 1, varsayılan 1), `PageSize` (1–200, varsayılan 50). Sıra: belge tarihi azalan, sonra `CariBelgeId` azalan.

```json
{ "IsSuccessful": true, "MessageCode": 200, "Message": "İşlem başarılı.",
  "Data": {
    "Items": [ { "CariBelgeId": 29, "CariBelgeTipiId": 7, "CariBelgeTipi": "Açılış", "Sign": 1, "CariBelgeNo": "API-1",
                 "CariBelgeTarihi": "2026-10-10", "DovizBirimiId": 1, "DovizBirimi": "TRL", "OdemeVadeId": 1,
                 "KalemSayisi": 2, "ToplamTutar": 133.55 } ],
    "TotalCount": 1, "Page": 1, "PageSize": 50 } }
```

- `CariBelgeNo` boş olabilir (`null`); benzersiz olması gerekmez.
- `ToplamTutar` kalemlerin toplamıdır; tutarı boş (`null`) kalem 0 sayılır. Kalemsiz belgede `KalemSayisi` 0 ve `ToplamTutar` 0'dır.
- Cari yoksa ya da başka tenant'a aitse `1004`; `Page`/`PageSize` geçersizse `1003`.

#### 6B.3.3 `GET /api/v1/fi/cari-belge/{CariBelgeId}` — tek belge, kalemleriyle (yetki: `CariBelgeler`)

```json
{ "IsSuccessful": true, "MessageCode": 200, "Message": "İşlem başarılı.",
  "Data": {
    "CariBelgeId": 29, "CariId": 5582, "CariBelgeTipiId": 7, "CariBelgeTipi": "Açılış", "Sign": 1, "CariBelgeNo": "API-1",
    "CariBelgeTarihi": "2026-10-10", "DovizBirimiId": 1, "DovizBirimi": "TRL", "OdemeVadeId": 1,
    "Kalemler": [ { "CariBelgeKalemId": 51, "StokKartiId": null, "Miktar": 1.0, "BirimId": 1, "Birim": "Adet", "Tutar": 123.45 } ] } }
```

- Stok kartı adı döndürülmez; yalnızca `StokKartiId`.
- Kalemin `Tutar`'ı `null` olabilir (taşınan eski kayıtlarda); form bu durumda boş gösterir ve kaydetmeden önce değer ister.
- Yoksa ya da başka tenant'a aitse `1004`. Belge pasif bir belge tipindeyse `CariBelgeTipi` yine adıyla gelir.

#### 6B.3.4 `POST /api/v1/fi/cari-belge` — kaydet (yetki: `CariBelgeler` + `KAYDET`)

`CariBelgeId` yok ya da `0` → yeni belge; dolu → güncelleme (`CariId` değiştirilemez, `1003`).

```json
{ "CariBelgeId": 29, "CariId": 5582, "CariBelgeTipiId": 7, "CariBelgeNo": "API-1", "CariBelgeTarihi": "2026-10-10",
  "DovizBirimiId": 1, "OdemeVadeId": 1,
  "Kalemler": [ { "CariBelgeKalemId": 51, "Miktar": 1, "BirimId": 1, "Tutar": 123.45 },
                { "Miktar": 2.5, "BirimId": 1, "Tutar": 10.10 } ] }
```

| Alan | Kural |
|---|---|
| `CariBelgeId` | int ≥ 0, opsiyonel |
| `CariId` | **zorunlu**, int > 0 |
| `CariBelgeTipiId` | **zorunlu**; geçerli (aktif) tip olmalı (`1003`). Güncellemede belge pasif bir tipteyse **aynı tipte kalabilir**; pasif bir tipe geçilemez |
| `CariBelgeNo` | ≤ 20 karakter, opsiyonel |
| `CariBelgeTarihi` | **zorunlu**, metin, `yyyy-MM-dd` (geçerli tarih; `Date`'e çevrilip saat dilimiyle gönderilmez) |
| `DovizBirimiId` | **zorunlu**; §6B.3.1'deki listede olmalı |
| `OdemeVadeId` | opsiyonel; yoksa sunucu "Peşin" (1) varsayılanını kullanır, güncellemede mevcut değer korunur |
| `Kalemler` | dizi, en çok 200 öğe (aşağıya bakın) |

Kalem alanları:

| Alan | Kural |
|---|---|
| `CariBelgeKalemId` | yok ya da 0 → yeni kalem; dolu → bu belgenin mevcut kalemi (başka belgenin kalemi `1003`) |
| `Miktar` | opsiyonel (yoksa 1); > 0, en çok 4 ondalık |
| `BirimId` | **zorunlu**; §6B.3.1'deki listede olmalı (`1003`) |
| `Tutar` | **zorunlu**; ≥ 0 (0 geçerli), en çok 2 ondalık |
| `StokKartiId` | yalnızca `EntegrasyonTuru = Netsis` kümesinde yazılır; `Yok` kümesinde sunucu yok sayar (yeni kalemde boş kalır, güncellemede mevcut değer korunur). Mevcut bir `StokKartiId` Netsis kümesinde gönderilmezse silinir |

**Tam liste kuralı:** `Kalemler` özelliği **gönderildiyse** liste tam sayılır: listede olmayan mevcut kalemler silinir (soft delete). Boş dizi bütün
kalemleri siler. `Kalemler` hiç gönderilmezse kalemlere dokunulmaz. Shell'in belge formu her zaman `Kalemler`'i, ekrandaki kalem satırlarının
tamamıyla gönderir. **Yeni belgede en az 1 kalem zorunludur** (`1002`); mevcut belge kalemsiz kaydedilebilir.

Tutar ve miktar JSON sayısı olarak gönderilir. Sunucu sınırı aşan ondalığı **yuvarlamaz**, `1003` ile reddeder; istemci ondalık sınırını
gönderimden önce kendisi uygular. İstemci toplamı hesaplarken kayan nokta hatası yapmamak için tutarları kuruş (tam sayı) olarak toplar.

Başarı: `Data: { "CariBelgeId": 29 }`.

#### 6B.3.5 `DELETE /api/v1/fi/cari-belge/{CariBelgeId}` — sil (yetki: `CariBelgeler` + `SIL`)

Soft delete; belge ve kalemleri birlikte silinir. Başarıda `IsSuccessful: true`, `Data: { "CariBelgeId": … }`. Zaten silinmişse `1005`; yoksa `1004`.

### 6B.4 Doğrulama sınırları (Node katmanı, HTTP 422 / `2002`)

Sunucu aynı kuralları iki katmanda uygular: önce Node (Joi), sonra SP. İstemci doğrulaması bunlarla aynı kuralları kullanır:
`CariBelgeNo` ≤ 20, `CariBelgeTarihi` `^\d{4}-\d{2}-\d{2}$`, `Kalemler` ≤ 200 öğe, `Miktar` > 0 ve ≤ 999999999999999 (4 ondalık),
`Tutar` ≥ 0 ve ≤ 9999999999999.99 (2 ondalık), `BirimId` zorunlu, `Tutar` zorunlu.

### 6B.5 Cari'ye özgü kodlar (belgeler)

| Kod | Anlam | Shell davranışı |
|---|---|---|
| 1002 | Zorunlu alan eksik (cari, tip, tarih, döviz, yeni belgede kalem, kalemde birim/tutar) | Mesaj formda gösterilir |
| 1003 | Geçersiz değer (tarih, tip, döviz, vade, birim, miktar/tutar, kalem bu belgeye ait değil, belgenin carisi değiştirilemez) | Mesaj formda; kalem hatası ilgili kalem satırında |
| 1004 | Cari ya da belge bulunamadı | "Kayıt bulunamadı", listeyi yenile |
| 1005 | Belge zaten silinmiş | Bilgi mesajı, listeyi yenile |

`1203` (Netsis'e bağlı cari) belgeler için **yoktur**.

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
- Fontlar (Roboto) pubspec'e gömülüdür; `web/flutter_bootstrap.js` yedek font adresini kendi origin'ine çevirir,
  böylece çalışma anında hiçbir dış adrese istek gitmez.
- Hedef: sunucuda `C:\OptiCodeWeb\test\web`. Kopyalarken sunucudaki `web.config` **korunur**
  (`robocopy <build\web> C:\OptiCodeWeb\test\web /MIR /XF web.config`). Repodaki `web/web.config` yalnızca bir örnektir ve pakete
  **konmaz**; IIS kuralları (SPA yönlendirmesi, `/api` proxy, güvenlik başlıkları) sunucuda hazırdır.
- Paketleme ve adımlar: `tools/build-web.ps1`, `docs/deployment.md`.
- `index.html` ve `flutter_bootstrap.js` IIS tarafından `no-cache` ile sunulur.
- CSP şu an `Report-Only`; tarayıcı konsolunda CSP ihlali olmamalıdır.
