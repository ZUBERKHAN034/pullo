#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
command -v pngquant >/dev/null || { echo "pngquant is required: brew install pngquant" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
swift Tools/icon/make-icon.swift "$work/icon.png"

for size in 16 32 128 256 512; do
  sips -z $size $size "$work/icon.png" --out "$work/$size.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$work/icon.png" --out "$work/$size@2x.png" >/dev/null
done
pngquant --quality 85-100 --speed 1 --strip --force --ext .png "$work"/*.png

set="$work/AppIcon.iconset"
mkdir "$set"
for size in 16 32 128 256 512; do
  cp "$work/$size.png" "$set/icon_${size}x${size}.png"
  cp "$work/$size@2x.png" "$set/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$set" -o "$work/apple.icns"

python3 - "$work" Resources/AppIcon.icns <<'PY'
import struct, sys
work, out = sys.argv[1], sys.argv[2]

apple = open(f"{work}/apple.icns", "rb").read()
small = {}
offset = 8
while offset < len(apple):
    kind, length = apple[offset:offset + 4].decode(), struct.unpack(">I", apple[offset + 4:offset + 8])[0]
    if kind in ("ic04", "ic05"):
        small[kind] = apple[offset:offset + length]
    offset += length

png = [("ic11", "16@2x"), ("ic12", "32@2x"), ("ic07", "128"), ("ic13", "128@2x"),
       ("ic08", "256"), ("ic14", "256@2x"), ("ic09", "512"), ("ic10", "512@2x")]
body = small["ic04"] + small["ic05"]
for kind, name in png:
    data = open(f"{work}/{name}.png", "rb").read()
    body += kind.encode() + struct.pack(">I", len(data) + 8) + data
open(out, "wb").write(b"icns" + struct.pack(">I", len(body) + 8) + body)
PY
echo Resources/AppIcon.icns
