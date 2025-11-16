#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

APP_NAME="Summon"
VERSION="${VERSION:-0.0.1}"
BUILD_DIR=".build/macos"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Packaging ${APP_NAME} v${VERSION}"

rm -rf "${APP_BUNDLE}"
./scripts/build.sh release

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

[ -d "assets/Resources/web-icons" ] && cp -r "assets/Resources/web-icons" "${RESOURCES_DIR}/"

if [ -f "assets/summon.icns" ]; then
    cp "assets/summon.icns" "${RESOURCES_DIR}/AppIcon.icns"
elif [ -f "assets/summon-icon.svg" ]; then
    ICONSET="/tmp/summon-iconset.iconset"
    mkdir -p "$ICONSET"

    if command -v rsvg-convert &>/dev/null; then
        for size in 16 32 64 128 256 512 1024; do
            rsvg-convert -w $size -h $size assets/summon-icon.svg -o "$ICONSET/icon_${size}x${size}.png"
        done
    else
        for size in 16 32 64 128 256 512 1024; do
            sips -s format png -z $size $size assets/summon-icon.svg --out "$ICONSET/icon_${size}x${size}.png" 2>/dev/null
        done
    fi

    for size in 16 32 64 128 256 512; do
        [ -f "$ICONSET/icon_$((size*2))x$((size*2)).png" ] && cp "$ICONSET/icon_$((size*2))x$((size*2)).png" "$ICONSET/icon_${size}x${size}@2x.png"
    done

    iconutil -c icns "$ICONSET" -o "${RESOURCES_DIR}/AppIcon.icns" 2>/dev/null || true
    rm -rf "$ICONSET"
fi
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.summon.app</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"
echo "Created: ${APP_BUNDLE}"
