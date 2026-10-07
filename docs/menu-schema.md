# Menü Şeması, API Sözleşmesi ve Mock Veri

> **Not (Faz 4):** Bu doküman **mock modun** sözleşmesidir. Gerçek modda `docs/api-contract.md` geçerlidir ve
> bu dokümandaki şunlar gerçek mod için **geçersizdir**: §1'deki uç noktalar ve hata gövdesi
> (`{ "code", "message" }`; gerçekte `IsSuccessful/Message/MessageCode/Data` zarfı), login/refresh
> istek-cevap gövdeleri (refresh token gövdede değil `httpOnly` cookie'de), `/me/menu` (menü istemcide
> tanımlanır, `/me` ile süzülür) ve §4'teki `auth.tokens` anahtarı (access token yalnızca bellekte).
> Mock repository'ler bu biçimde kalır; çeviri `Http*` repository'lerinde yapılır.

Mock verinin şekli, ileride backend'in uyması gereken **API sözleşmesidir**. Mock JSON dosyaları `assets/mock/` altında bu şekle birebir uymalıdır.

## 1. Uç noktalar

| Metot | Yol | Amaç |
|---|---|---|
| POST | `/auth/login` | Giriş |
| POST | `/auth/refresh` | Token yenileme |
| POST | `/auth/logout` | Çıkış |
| GET | `/me/menu` | Kullanıcının rol/istisna birleşiminden oluşan menü ağacı |
| GET | `/me/favorites` | Kullanıcının favori modülleri (Faz 2; mock'ta var, gerçek API Faz 4) |
| PUT | `/me/favorites/{moduleKey}` | Favoriye ekle (idempotent) |
| DELETE | `/me/favorites/{moduleKey}` | Favoriden çıkar (idempotent) |

Hata gövdesi (tüm uç noktalar): `{ "code": "string", "message": "string" }`. Beklenen HTTP kodları: 401 (oturum yok/süresi doldu), 403 (yetki yok).

### POST /auth/login

```json
// istek
{ "username": "yonetici", "password": "1234" }
// yanıt
{
  "accessToken": "…",
  "refreshToken": "…",
  "expiresInSeconds": 900,
  "user": { "id": 1, "displayName": "Yönetici Kullanıcı", "roles": ["Yonetici"] }
}
```

### POST /auth/refresh

```json
{ "refreshToken": "…" }
// yanıt: login yanıtı ile aynı token alanları
```

### GET /me/menu

Yanıt **iç içe (nested) ağaçtır**. Veritabanında düz tutulur, API ağaç olarak döner.

```json
{
  "menu": [
    {
      "id": 1,
      "title": "Satış",
      "icon": "shopping_cart",
      "moduleKey": null,
      "sortOrder": 10,
      "badge": null,
      "permissions": null,
      "children": [
        {
          "id": 11,
          "title": "Siparişler",
          "icon": "receipt_long",
          "moduleKey": "siparis",
          "sortOrder": 10,
          "badge": null,
          "permissions": { "canView": true, "canAdd": true, "canEdit": true, "canDelete": false },
          "children": []
        }
      ]
    }
  ]
}
```

### GET /me/favorites

Favoriler kullanıcı bazlıdır ve sunucuda tutulur (farklı cihaz/tarayıcıda da aynı liste). Sıra, eklenme sırasıdır. Menüde görünmeyen (yetkisi kalkmış) modüller istemcide gösterilmez.

```json
{ "favorites": ["siparis", "rapor-stok"] }
```

`PUT` ve `DELETE` gövde almaz; başarıda `204 No Content` döner.

Alan kuralları:

| Alan | Kural |
|---|---|
| `id` | Tekil sayı |
| `title` | Kullanıcıya görünen ad (backend'den Türkçe gelir) |
| `icon` | Material ikon **adı** (string). Flutter tarafında `core/icons/icon_registry.dart` içindeki `Map<String, IconData>` ile çözülür; bilinmeyen ad → varsayılan ikon |
| `moduleKey` | Yaprak düğümlerde dolu, gruplarda `null`. Flutter'daki `registry.dart` anahtarıyla eşleşir |
| `sortOrder` | Aynı seviyedeki kardeşler arasında artan sıra |
| `badge` | `null` ya da kısa metin/sayı (ör. `"5"`); doluysa menüde rozet olarak gösterilir |
| `permissions` | Yaprak düğümlerde dolu, gruplarda `null`. `canView` false olan düğüm **hiç gönderilmez** |
| `children` | Yaprakta boş dizi. En fazla 3 seviye |

İstemci kuralları:
- `moduleKey` registry'de yoksa menüde gösterilir ama açılınca "Modül bulunamadı" ekranı çıkar (demo ortamında uyarı logu).
- Hiç yaprağı olmayan grup gizlenir.

## 2. Yetki modeli

Veri modeli (backend için referans):

```
Module(Id, ParentId, Title, Icon, ModuleKey, SortOrder, IsActive)
Role(Id, Name)
RoleModule(RoleId, ModuleId, CanView, CanAdd, CanEdit, CanDelete)
UserRole(UserId, RoleId)
UserModuleOverride(UserId, ModuleId, CanView, CanAdd, CanEdit, CanDelete)  -- null = istisna yok
```

Etkin yetki hesabı (sunucu tarafında yapılır, `/me/menu` sonucuna yansır):
1. Kullanıcının tüm rollerindeki yetkiler **birleştirilir** (her bayrak için OR).
2. `UserModuleOverride` içinde `null` olmayan değer varsa ilgili bayrağı **ezer** (ekleme de çıkarma da olabilir).
3. `canView` false ise modül menüde yoktur.

Menüde gizlemek yalnızca UX'tir; API her istekte yetkiyi kendisi doğrular.

## 3. Mock veri (Faz 1)

Mock giriş bilgileri yalnızca demo içindir. Şifre doğrulaması yapılmaz; kullanıcı adı seçimi yeterlidir.

| Kullanıcı adı | Şifre | Rol | Amaç |
|---|---|---|---|
| `yonetici` | `1234` | Yonetici | Tüm menü, tüm yetkiler |
| `depo` | `1234` | Depo | Depo grubu tam yetkili, Raporlar ve Siparişler salt okunur (Faz 3 yetki örneği: "Yeni", "Kaydet", "Sil" görünmez) |
| `satis` | `1234` | Satis | Satış grubu tam yetkili (silme yok) |

Mock `Yonetici` menüsü (diğerleri bunun alt kümesidir):

```
Satış
  ├─ Siparişler        (siparis)         ← Faz 3'te liste → detay örnek modülü
  └─ Müşteriler        (musteri)
Depo
  ├─ Stok Durumu       (stok)
  └─ Sevkiyat          (sevkiyat)
Raporlar
  └─ Satış Raporu      (rapor-satis)
Ayarlar
  └─ Kullanıcılar      (kullanici)       ← yalnızca Yonetici
```

Mock modüller Faz 1'de yalnızca başlık ve `permissions` bilgisini gösteren **boş sayfalar**dır. Faz 3'te `siparis` modülü liste → detay örneğine dönüştürülür.

Mock'un desteklemesi gerekenler:
- Yapay gecikme (300–600 ms) ve yükleniyor durumu.
- Gizli bir geliştirici komutu: kullanıcı menüsünde (yalnızca `USE_MOCK=true` iken) **"Oturum süresini doldur"** düğmesi; sonraki API çağrısını 401 yaptırarak oturum sona erme akışını test ettirir.
- Kullanıcı bazlı `badge` örneği: `depo` kullanıcısında "Sevkiyat" için `"3"`.

## 4. Depolama anahtarları

| Anahtar | Depo | İçerik |
|---|---|---|
| `ui.menu.collapsed` | localStorage | Menü daralmış mı |
| `ui.menu.expanded.<userId>` | localStorage | Açık grup id'leri |
| `ui.theme` | localStorage | `light` / `dark` / `system` |
| `ui.locale` | localStorage | Dil kodu |
| `ui.tabs.<userId>` | sessionStorage | Açık sekmeler (modül + query) ve aktif sekme (Faz 2). Sabit sekmeler kaydedilmez |
| `ui.recent.<userId>` | localStorage | Son kullanılan 5 modül, en yenisi başta (Faz 2) |
| `auth.logoutSignal` | localStorage | Çıkışta yazılır; diğer tarayıcı sekmeleri `storage` olayıyla çıkış yapar (Faz 2) |
| `mock.favorites.<username>` | localStorage | Yalnızca mock: favori API'sinin "sunucu" tarafı |
| `ui.grid.<userId>.<moduleKey>.<gridId>` | localStorage | Sütun sırası/genişlik/görünürlük (Faz 3). `ui-behaviors.md` "kullanıcı bazında" dediği için anahtara `userId` eklendi |
| `auth.tokens` | sessionStorage | Token'lar (gerçek API fazında yeniden değerlendirilecek) |

## 5. Liste sorgu sözleşmesi ve Siparişler API'si (Faz 3)

Tüm listeler (`AppDataGrid`) sunucu taraflı sayfalama/sıralama/filtre için aynı **JSON gövdeli POST** biçimini kullanır:

```json
// POST /<kaynak>/query
{
  "page": 1,                // 1'den başlar
  "pageSize": 25,
  "sort": [{ "field": "tarih", "dir": "desc" }],          // dir: asc | desc
  "filters": [
    { "field": "durum",   "op": "eq",       "value": "Acik" },
    { "field": "musteri", "op": "contains", "value": "ahmet" },
    { "field": "tarih",   "op": "gte",      "value": "2026-01-01" },
    { "field": "tarih",   "op": "lte",      "value": "2026-01-31" }
  ]
}
// yanıt
{ "items": [ ... ], "total": 312 }   // total: filtreye uyan tüm kayıt sayısı
```

Operatörler: `eq`, `contains` (Türkçe büyük/küçük harf ve `İ/ı` duyarsız), `gte`, `lte` (tarih `yyyy-MM-dd`, sayı). Filtreler AND ile birleşir. CSV dışa aktarma aynı sorguyu büyük `pageSize` ile gönderir.

### Siparişler

| Metot | Yol | Amaç |
|---|---|---|
| POST | `/siparisler/query` | Liste (yukarıdaki sözleşme). Alanlar: `no`, `musteri`, `tarih`, `durum`, `tutar` |
| GET | `/siparisler/{id}` | Başlık + kalemler; yoksa `404` |
| POST | `/siparisler` | Yeni sipariş; `id` ve `no` sunucuda verilir |
| PUT | `/siparisler/{id}` | Güncelle |
| DELETE | `/siparisler/{id}` | Sil |

```json
// Liste satırı
{ "id": 5, "no": "SP-1005", "musteri": "Ege Tekstil", "tarih": "2026-09-26",
  "durum": "Onaylandi", "tutar": 2501.0 }

// Detay (GET/POST/PUT gövdesi)
{
  "id": 5, "no": "SP-1005", "musteri": "Ege Tekstil", "tarih": "2026-09-26",
  "durum": "Onaylandi",                 // Acik | Onaylandi | SevkEdildi | Iptal
  "teslimAdresi": "Bornova / İzmir", "not": "",
  "kalemler": [ { "urun": "Rulman 6204", "miktar": 2, "birimFiyat": 1250.5 } ]
}
```

`tutar` sunucuda kalemlerden hesaplanır (`miktar × birimFiyat` toplamı). Yetki: listeleme `canView`, yeni `canAdd`, güncelleme `canEdit`, silme `canDelete`; API her istekte kendisi doğrular.

Mock: 137 sipariş deterministik üretilir (`MockSiparisRepository`), değişiklikler sayfa oturumu boyunca bellekte tutulur.
