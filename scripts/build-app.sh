#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi

echo "→ Regenerating Xcode project"
xcodegen generate >/dev/null

echo "→ Building universal Release app"
rm -rf build-release
xcodebuild \
    -project SpecForge.xcodeproj \
    -scheme SpecForge \
    -configuration Release \
    -derivedDataPath build-release \
    -destination 'generic/platform=macOS' \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet \
    build

APP_SOURCE="build-release/Build/Products/Release/SpecForge.app"
APP_DEST="dist/SpecForge.app"

echo "→ Signing app (ad-hoc)"
rm -rf dist
mkdir -p dist
cp -R "$APP_SOURCE" "$APP_DEST"
xattr -cr "$APP_DEST"
codesign --force --deep --sign - --options runtime "$APP_DEST"
codesign --verify --deep --strict "$APP_DEST"

echo "→ Creating ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_DEST" "dist/SpecForge.zip"

echo "→ Creating DMG"
STAGING="dist/.dmg-staging"
mkdir -p "$STAGING"
cp -R "$APP_DEST" "$STAGING/SpecForge.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
    -volname "SpecForge" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "dist/SpecForge.dmg" >/dev/null
rm -rf "$STAGING"

echo
echo "Done:"
echo "  dist/SpecForge.app"
echo "  dist/SpecForge.zip"
echo "  dist/SpecForge.dmg"
