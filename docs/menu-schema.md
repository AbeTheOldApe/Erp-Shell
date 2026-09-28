# Menü Şeması, API Sözleşmesi ve Mock Veri

Mock verinin şekli, ileride backend'in uyması gereken **API sözleşmesidir**. Mock JSON dosyaları `assets/mock/` altında bu şekle birebir uymalıdır.

## 1. Uç noktalar

| Metot | Yol | Amaç |
|---|---|---|
| POST | `/auth/login` | Giriş |
| POST | `/auth/refresh` | Token yenileme |
| POST | `/auth/logout` | Çıkış |
| GET | `/me/menu` | Kullanıcının rol/istisna birleşiminden oluşan menü ağacı |

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
| `depo` | `1234` | Depo | Depo grubu tam yetkili, Raporlar salt okunur |
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
| `ui.tabs.<userId>` | sessionStorage | Açık sekmeler ve aktif sekme (Faz 2) |
| `ui.grid.<moduleKey>.<gridId>` | localStorage | Sütun sırası/genişlik/görünürlük (Faz 3) |
| `auth.tokens` | sessionStorage | Token'lar (gerçek API fazında yeniden değerlendirilecek) |
