#!/bin/bash
set -euo pipefail

APP_NAME="Summon"
VERSION="${VERSION:-0.0.1}"
BUILD_DIR=".build/macos"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Packaging ${APP_NAME} v${VERSION}..."

rm -rf "${APP_BUNDLE}"
./scripts/build-release.sh

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"
cp target/release/libffi.dylib "${MACOS_DIR}/"

install_name_tool -change \
    "@rpath/libffi.dylib" \
    "@executable_path/libffi.dylib" \
    "${MACOS_DIR}/${APP_NAME}"
if [ -f "assets/summon.icns" ]; then
    cp "assets/summon.icns" "${RESOURCES_DIR}/AppIcon.icns"
elif [ -f "assets/summon-icon.svg" ]; then
    if command -v rsvg-convert &> /dev/null; then
        mkdir -p /tmp/summon-iconset.iconset

        for size in 16 32 64 128 256 512 1024; do
            rsvg-convert -w $size -h $size assets/summon-icon.svg -o /tmp/summon-iconset.iconset/icon_${size}x${size}.png
        done
        for size in 16 32 64 128 256 512; do
            cp /tmp/summon-iconset.iconset/icon_${size}x${size}.png /tmp/summon-iconset.iconset/icon_$((size/2))x$((size/2))@2x.png
        done
        iconutil -c icns /tmp/summon-iconset.iconset -o "${RESOURCES_DIR}/AppIcon.icns"
        rm -rf /tmp/summon-iconset.iconset
    else
        echo "Warning: rsvg-convert not available, falling back to sips"
        mkdir -p /tmp/summon-iconset.iconset

        for size in 16 32 64 128 256 512 1024; do
            sips -s format png -z $size $size assets/summon-icon.svg --out /tmp/summon-iconset.iconset/icon_${size}x${size}.png 2>/dev/null
        done

        for size in 16 32 128 256 512; do
            double=$((size * 2))
            cp /tmp/summon-iconset.iconset/icon_${double}x${double}.png /tmp/summon-iconset.iconset/icon_${size}x${size}@2x.png 2>/dev/null || true
        done

        iconutil -c icns /tmp/summon-iconset.iconset -o "${RESOURCES_DIR}/AppIcon.icns" 2>/dev/null || true
        rm -rf /tmp/summon-iconset.iconset
    fi
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
echo "Package created: ${APP_BUNDLE}"
