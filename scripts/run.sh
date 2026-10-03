#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh
pkill -x DevNotch || true
open build/DevNotch.app
