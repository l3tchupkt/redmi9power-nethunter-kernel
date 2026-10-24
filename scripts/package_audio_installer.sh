#!/usr/bin/env bash
# ==============================================================================
# Xiaomi Chime/Lime Audio Kernel Recovery Package Builder (v2.8)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
SRC_INSTALLER="${SRC_INSTALLER:-$REPO_ROOT/../boot20/chime-audio-test}"
SRC_ROLLBACK="${SRC_ROLLBACK:-$REPO_ROOT/../boot20/chime-audio-rollback}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"

mkdir -p "$OUT_DIR"

if [ ! -d "$SRC_INSTALLER" ] || [ ! -d "$SRC_ROLLBACK" ]; then
    echo "ERROR: Source staging directories not found."
    echo "  Installer staging: $SRC_INSTALLER"
    echo "  Rollback staging : $SRC_ROLLBACK"
    exit 1
fi

echo "--- Building chime-audio-test-v2.zip ---"
cd "$SRC_INSTALLER"
zip -r -q "$OUT_DIR/chime-audio-test-v2.zip" META-INF audio_modules install.sh manifest.sha256 manifest.txt

echo "--- Building chime-audio-rollback-v2.zip ---"
cd "$SRC_ROLLBACK"
zip -r -q "$OUT_DIR/chime-audio-rollback-v2.zip" META-INF rollback.sh

echo "=================================================="
echo " Audio Recovery Packages Generated:"
sha256sum "$OUT_DIR/chime-audio-test-v2.zip" "$OUT_DIR/chime-audio-rollback-v2.zip"
echo "=================================================="