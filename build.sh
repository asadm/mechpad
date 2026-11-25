#!/bin/sh
# Builds MechPad.app (macOS native app, zero external dependencies).
#
#   ./build.sh            build for this Mac's architecture (fast)
#   ./build.sh universal  build universal binary (Apple Silicon + Intel)
set -e
cd "$(dirname "$0")"

MODE="${1:-native}"
APP_NAME="MechPad"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

SOURCES="
Sources/HapticEngine.swift
Sources/SwitchProfiles.swift
Sources/KeyboardMonitor.swift
Sources/AppState.swift
Sources/ContentView.swift
Sources/main.swift
"

FRAMEWORKS="
-framework AppKit
-framework SwiftUI
-framework IOKit
-framework ApplicationServices
-framework Carbon
-framework ServiceManagement
"

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

if [ "${MODE}" = "universal" ]; then
    mkdir -p build
    echo "Building ${APP_NAME} for Apple Silicon (arm64)..."
    swiftc -O -target arm64-apple-macos13 ${FRAMEWORKS} ${SOURCES} -o "build/${APP_NAME}-arm64"
    echo "Building ${APP_NAME} for Intel (x86_64)..."
    swiftc -O -target x86_64-apple-macos13 ${FRAMEWORKS} ${SOURCES} -o "build/${APP_NAME}-x86_64"
    lipo -create "build/${APP_NAME}-arm64" "build/${APP_NAME}-x86_64" -output "${MACOS_DIR}/${APP_NAME}"
else
    ARCH="$(uname -m)"
    echo "Building ${APP_NAME} for ${ARCH}..."
    swiftc -O -target "${ARCH}-apple-macos13" ${FRAMEWORKS} ${SOURCES} -o "${MACOS_DIR}/${APP_NAME}"
fi

cp Icon/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
cp -R Localization/*.lproj "${RESOURCES_DIR}/"

cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MechPad</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.mechpad.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MechPad</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ru</string>
        <string>he</string>
        <string>de</string>
        <string>es</string>
        <string>fr</string>
        <string>ja</string>
        <string>zh-Hans</string>
    </array>
    <key>CFBundleDisplayName</key>
    <string>MechPad</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "${BUNDLE_DIR}" 2>/dev/null || true

echo "Built ${BUNDLE_DIR} ($(lipo -archs "${MACOS_DIR}/${APP_NAME}"))."
echo "Run with: open ${BUNDLE_DIR}"
