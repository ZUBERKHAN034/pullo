#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/DevNotch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/DevNotch "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# A stable signing identity keeps Keychain access across rebuilds; ad-hoc signing would re-prompt every time.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "$APP"
