#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Launch at login points at the app's location, so it has to live somewhere that survives rebuilds.
./scripts/build.sh
pkill -x DevNotch || true
rm -rf /Applications/DevNotch.app
cp -R build/DevNotch.app /Applications/
open /Applications/DevNotch.app
echo "Instalado em /Applications/DevNotch.app"
