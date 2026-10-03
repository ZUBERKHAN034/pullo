#!/usr/bin/env bash
# Records the scripted tour and rebuilds docs/media from it.
# Needs Screen Recording permission for DevNotch the first time (System Settings › Privacy & Security).
set -euo pipefail
cd "$(dirname "$0")/../.."

./scripts/build.sh
pkill -x DevNotch || true
rm -rf build/demo-raw
# Run the binary itself: launched through `open`, the recording permission didn't stick.
./build/DevNotch.app/Contents/MacOS/DevNotch --demo --record build/demo-raw
if [[ -f build/demo-raw/error.txt ]]; then
  cat build/demo-raw/error.txt >&2
  exit 1
fi
python3 scripts/demo/make-media.py
