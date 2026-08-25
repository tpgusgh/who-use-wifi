#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WhoUseWifi"
BUILD_DIR=".build/release"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

swift build -c release

rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Sources/$APP_NAME/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DIST_DIR/$APP_NAME.dmg"

echo "dmg 생성 완료: $DIST_DIR/$APP_NAME.dmg"
