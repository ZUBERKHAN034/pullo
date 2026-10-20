#!/usr/bin/env bash
set -euo pipefail

app="$1"
framework="$app/Contents/Frameworks/Sparkle.framework"

while IFS= read -r -d '' file; do
  if lipo -archs "$file" 2>/dev/null | grep -q x86_64; then
    lipo -remove x86_64 "$file" -output "$file"
  fi
done < <(find "$framework" -type f -print0)

sign() {
  codesign --force --timestamp --options runtime --sign "Developer ID Application" \
    --preserve-metadata=identifier,entitlements,requirements,flags "$@"
}

sign "$framework/Versions/B/XPCServices/Installer.xpc"
sign "$framework/Versions/B/XPCServices/Downloader.xpc"
sign "$framework/Versions/B/Autoupdate"
sign "$framework/Versions/B/Updater.app"
sign "$framework"
sign "$app"
codesign --verify --deep --strict "$app"
