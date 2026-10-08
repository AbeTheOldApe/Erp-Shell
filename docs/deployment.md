# Test sunucusuna dağıtım

Hedef: `https://test.opticode.com.tr` (statik dosyalar `/`, API `/api/v1`, aynı origin). Sunucudaki
`C:\OptiCodeWeb\test\web` klasörü IIS'in sunduğu klasördür.

> **Sunucudaki `web.config`'e asla dokunulmaz.** SPA yönlendirmesi, `/api` proxy'si ve güvenlik
> başlıkları orada hazırdır. Aşağıdaki adımlar onu hem pakete koymaz hem de kopyalarken hariç tutar.

## 1. Paketi üret (geliştirme makinesi)

Repo kökünden:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build-web.ps1
```

Betik şunları yapar:

1. `flutter build web --release --no-web-resources-cdn --dart-define=USE_MOCK=false`
2. Çıktıyı denetler ve sorun bulursa **uyarır** (zip yine de yazılır; `-FailOnWarning` ile çıkış kodu 2 olur):
   - `config.json` build'de var mı, `useMock: false` ve `apiBaseUrl: /api/v1` mi
   - `index.html` içinde `<base href="/">` var mı
   - `flutter_bootstrap.js` CanvasKit'i yerelden yüklüyor ve yedek font adresini kendi origin'ine çeviriyor mu
   - build'de tarayıcının çağıracağı başka bir dış adres (gstatic, googleapis, CDN vb.) geçiyor mu
     (Flutter motorundaki yalnızca doküman/hata bağlantıları ve ayarımızla geçersiz kılınan varsayılan
     gstatic adresleri "info" olarak listelenir; istek üretmez)
3. `build\web` klasörünü `dist\erp-shell-web-<kısa commit>.zip` olarak paketler. Çalışma ağacında
   commit edilmemiş değişiklik varsa ad `-dirty` ile biter; **dağıtım için temiz bir commit kullanın.**
   Zip'e `web.config` **konmaz**.

`-SkipBuild` mevcut `build\web`'i yeniden derlemeden denetler ve paketler. `dist\` git'e girmez.

Fontlar (Roboto) `assets/fonts/Roboto/` altında pubspec'e gömülüdür; uygulama çalışırken Google
Fonts'a ya da başka bir dış adrese font isteği gitmez. Roboto'da olmayan karakterler (Kiril, emoji, CJK)
için yedek font indirilmez; bu karakterler kutucuk olarak görünür.

## 2. Sunucuya kopyala ve aç

1. `dist\erp-shell-web-<commit>.zip` dosyasını sunucuya kopyalayın (uzak masaüstü, paylaşım vb.).
2. Sunucuda `C:\OptiCodeWeb\test\deploy\` altında sürüme özel bir klasöre açın:

   ```powershell
   Expand-Archive C:\OptiCodeWeb\test\deploy\erp-shell-web-<commit>.zip `
     -DestinationPath C:\OptiCodeWeb\test\deploy\erp-shell-web-<commit>
   ```

3. Açılan klasörde `index.html`, `flutter_bootstrap.js`, `config.json`, `canvaskit\` ve `assets\`
   dosyalarının bulunduğunu doğrulayın (zip'in kökü doğrudan site köküdür; iç içe bir klasör olmamalı).

## 3. Yayına al

Açılan klasörden site klasörüne aynalayın; `web.config` hariç tutulur (ne kopyalanır ne silinir):

```powershell
robocopy C:\OptiCodeWeb\test\deploy\erp-shell-web-<commit> C:\OptiCodeWeb\test\web /MIR /XF web.config
```

- `/MIR` hedefte artık olmayan eski dosyaları siler (eski `main.dart.js` parçaları gibi). Bu yüzden
  **kaynak klasör eksiksiz olmalı**; yanlış klasörü verirseniz site boşalır. Önce `/L` ile deneyebilirsiniz:
  `robocopy <kaynak> C:\OptiCodeWeb\test\web /MIR /XF web.config /L`.
- Robocopy çıkış kodları 0–7 başarıdır (8 ve üzeri hata).
- `index.html` ve `flutter_bootstrap.js` IIS tarafından `no-cache` ile sunulur; kullanıcılar yeni sürümü
  sayfayı yenileyince alır.

## 4. Doğrula

`https://test.opticode.com.tr` adresinde: giriş, F5 (oturum sessizce geri gelir), "Menüyü yenile", çıkış,
Cari akışı. Tarayıcı geliştirici konsolunda **CSP ihlali** ve **dış adrese istek** (Ağ sekmesinde
`gstatic`, `googleapis` vb.) olmamalıdır.

## Geri alma

Önceki sürümün klasörü `deploy\` altında durur; aynı `robocopy` komutunu o klasörle çalıştırmak yeterlidir.
Eski klasörleri sunucuda yer açmak için elle silebilirsiniz.

## Yerel geliştirme

Dağıtım değildir; bkz. `tools/dev-proxy/README.md`.
