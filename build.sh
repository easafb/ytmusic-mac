#!/bin/bash
# YT Music.app'i derler. Kullanım:
#   ./build.sh            -> build/YT Music.app
#   ./build.sh --install  -> ayrıca /Applications klasörüne kopyalar
set -euo pipefail
cd "$(dirname "$0")"

APP="build/YT Music.app"
ICON="build/AppIcon.icns"

# Simge (yalnızca ilk seferde üretilir)
if [ ! -f "$ICON" ]; then
  echo "→ Simge üretiliyor"
  mkdir -p build/AppIcon.iconset
  swift scripts/make_icon.swift build/icon_1024.png
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon_1024.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) build/icon_1024.png --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns build/AppIcon.iconset -o "$ICON"
fi

echo "→ Derleniyor"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 \
  -target "$(uname -m)-apple-macos13.0" \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/YTMusic"

# Info.plist, Xcode değişkenleri kullanır; burada elle dolduruyoruz.
sed -e 's/$(EXECUTABLE_NAME)/YTMusic/' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/local.asafb.ytmusic/' \
    -e 's/$(MARKETING_VERSION)/1.0/' \
    -e 's/$(CURRENT_PROJECT_VERSION)/1/' \
    -e 's/$(MACOSX_DEPLOYMENT_TARGET)/13.0/' \
    Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/Bridge.js "$APP/Contents/Resources/"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

# Yerel (ad-hoc) imza: kendi Mac'inde çalıştırmak için yeterli.
codesign --force --deep --sign - "$APP"
echo "✓ Hazır: $APP"

if [ "${1:-}" = "--install" ]; then
  rm -rf "/Applications/YT Music.app"
  cp -R "$APP" /Applications/
  echo "✓ /Applications/YT Music.app kuruldu"
fi
