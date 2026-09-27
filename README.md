# YT Music (macOS)

music.youtube.com için hafif, native bir Mac uygulaması (Swift + WKWebView).

## İndir
[Son sürümü indir](https://github.com/easafb/ytmusic-mac/releases/latest) → zip'i aç, **YT Music.app**'i Programlar
klasörüne sürükle. Uygulama Apple onaylı olmadığı için ilk açılıştan önce Terminal'de:
```bash
xattr -dr com.apple.quarantine "/Applications/YT Music.app"
```
macOS 13+ · Apple Silicon ve Intel

## Özellikler
- Google hesabınla giriş (oturum kalıcı; Premium reklamsız çalışır)
- Klavye medya tuşları ve Kontrol Merkezi'nde "Şimdi Çalınıyor"
- Menü çubuğunda mini oynatıcı (sol tık); hızlı menü (sağ tık)
- Şarkı değişince bildirim (uygulama arka plandayken; menüden kapatılabilir)
- Pencereyi kapatınca müzik çalmaya devam eder, Dock simgesine tıklayınca geri gelir
- Kısayollar: ⌥⌘P oynat/duraklat, ⌥⌘→ / ⌥⌘← sonraki/önceki, ⌘R yenile, ⌘+ / ⌘− yakınlaştır

## Derleme
**Xcode ile:** `YTMusic.xcodeproj` dosyasını açıp ⌘R. `Sources/` ve `Resources/` klasörlerine
eklenen yeni dosyalar projeye otomatik dahil olur.

**Komut satırından** (Xcode gerekmez):
```bash
./build.sh            # build/YT Music.app
./build.sh --install  # ayrıca /Applications'a kurar
```
Yalnızca Command Line Tools yeterli (Xcode gerekmez).

## Dosyalar
- `Sources/PlayerController.swift`: web görünümü, sayfa ile köprü, gezinme kuralları
- `Resources/Bridge.js`: sayfaya enjekte edilen betik (şarkı bilgisi + komutlar)
- `Sources/NowPlaying.swift`: medya tuşları / Şimdi Çalınıyor
- `Sources/MenuBar.swift`: menü çubuğu mini oynatıcısı
- `Sources/TrackNotifier.swift`: bildirimler
- `Sources/AppDelegate.swift`: pencere ve menüler
