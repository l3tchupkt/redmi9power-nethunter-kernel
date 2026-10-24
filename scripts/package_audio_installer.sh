#!/usr/bin/env bash
# ==============================================================================
# Xiaomi Chime/Lime Audio Recovery Package Builder (v2.8)
# Packaging: chime-audio-test-v2.zip & chime-audio-rollback-v2.zip
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

# Configurable paths
SRC_INSTALLER="${SRC_INSTALLER:-$REPO_ROOT/../boot20/chime-audio-test}"
SRC_ROLLBACK="${SRC_ROLLBACK:-$REPO_ROOT/../boot20/chime-audio-rollback}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"

echo "=================================================="
echo " Audio Recovery Package Builder (v2.8)"
echo " Installer Staging : $SRC_INSTALLER"
echo " Rollback Staging  : $SRC_ROLLBACK"
echo " Output Directory  : $OUT_DIR"
echo "=================================================="

# --- Pre-flight Validation: Installer Staging ---
if [ ! -d "$SRC_INSTALLER" ]; then
    echo "ERROR: Installer staging directory does not exist: $SRC_INSTALLER" >&2
    exit 1
fi

if [ ! -f "$SRC_INSTALLER/install.sh" ] || [ ! -s "$SRC_INSTALLER/install.sh" ]; then
    echo "ERROR: install.sh missing or 0 bytes in $SRC_INSTALLER" >&2
    exit 1
fi

if [ ! -f "$SRC_INSTALLER/META-INF/com/google/android/update-binary" ]; then
    echo "ERROR: update-binary missing in $SRC_INSTALLER/META-INF/com/google/android/" >&2
    exit 1
fi

if [ ! -d "$SRC_INSTALLER/audio_modules" ]; then
    echo "ERROR: audio_modules directory missing in $SRC_INSTALLER" >&2
    exit 1
fi

MOD_COUNT=$(find "$SRC_INSTALLER/audio_modules" -name "audio_*.ko" | wc -l | tr -d ' ')
if [ "$MOD_COUNT" -ne 28 ]; then
    echo "ERROR: Expected exactly 28 audio modules in $SRC_INSTALLER/audio_modules, found $MOD_COUNT" >&2
    exit 1
fi

# Disallow disabled WSA881x driver
if find "$SRC_INSTALLER/audio_modules" -name "*wsa881x*" | grep -q .; then
    echo "FATAL: Disabled reference WSA881x driver found in staging! It must be excluded." >&2
    exit 1
fi

if grep -q "wsa881x" "$SRC_INSTALLER/manifest.sha256" 2>/dev/null; then
    echo "FATAL: WSA881x referenced in installer manifest.sha256! Aborting." >&2
    exit 1
fi

# Assert NO raw partition images exist in staging
if find "$SRC_INSTALLER" -name "*.img" 2>/dev/null | grep -q .; then
    echo "FATAL: Raw partition image (.img) found inside installer staging directory!" >&2
    echo "Raw device backups must NEVER be packaged into distributable ZIPs." >&2
    exit 1
fi

# --- Pre-flight Validation: Rollback Staging ---
if [ ! -d "$SRC_ROLLBACK" ]; then
    echo "ERROR: Rollback staging directory does not exist: $SRC_ROLLBACK" >&2
    exit 1
fi

if [ ! -f "$SRC_ROLLBACK/rollback.sh" ] || [ ! -s "$SRC_ROLLBACK/rollback.sh" ]; then
    echo "ERROR: rollback.sh missing or 0 bytes in $SRC_ROLLBACK" >&2
    exit 1
fi

if [ ! -f "$SRC_ROLLBACK/META-INF/com/google/android/update-binary" ]; then
    echo "ERROR: update-binary missing in $SRC_ROLLBACK/META-INF/com/google/android/" >&2
    exit 1
fi

if find "$SRC_ROLLBACK" -name "*.img" 2>/dev/null | grep -q .; then
    echo "FATAL: Raw partition image (.img) found inside rollback staging directory!" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
INSTALLER_ZIP="$OUT_DIR/chime-audio-test-v2.zip"
ROLLBACK_ZIP="$OUT_DIR/chime-audio-rollback-v2.zip"

rm -f "$INSTALLER_ZIP" "$ROLLBACK_ZIP"

echo "--- Packaging Installer: $INSTALLER_ZIP ---"
(cd "$SRC_INSTALLER" && zip -r -q "$INSTALLER_ZIP" META-INF audio_modules install.sh manifest.sha256 manifest.txt)

echo "--- Packaging Rollback: $ROLLBACK_ZIP ---"
(cd "$SRC_ROLLBACK" && zip -r -q "$ROLLBACK_ZIP" META-INF rollback.sh)

# --- Post-Packaging Integrity Checks ---
if command -v unzip >/dev/null 2>&1; then
    echo "--- Testing ZIP Integrity with unzip -t ---"
    unzip -t -q "$INSTALLER_ZIP"
    unzip -t -q "$ROLLBACK_ZIP"
    echo "  [+] Archive structure verified 100% OK."
fi

# Verify no .img files sneaked into the archives
if unzip -l "$INSTALLER_ZIP" | grep -i "\.img$" || unzip -l "$ROLLBACK_ZIP" | grep -i "\.img$"; then
    echo "FATAL: Archive contains a raw partition image (.img)! Aborting." >&2
    rm -f "$INSTALLER_ZIP" "$ROLLBACK_ZIP"
    exit 1
fi

echo "=================================================="
echo " Audio Recovery Packages Generated Successfully:"
echo " Installer : $INSTALLER_ZIP ($(stat -c%s "$INSTALLER_ZIP" 2>/dev/null || wc -c < "$INSTALLER_ZIP") bytes)"
if command -v sha256sum >/dev/null 2>&1; then
    echo "   SHA-256 : $(sha256sum "$INSTALLER_ZIP" | awk '{print $1}')"
fi
echo " Rollback  : $ROLLBACK_ZIP ($(stat -c%s "$ROLLBACK_ZIP" 2>/dev/null || wc -c < "$ROLLBACK_ZIP") bytes)"
if command -v sha256sum >/dev/null 2>&1; then
    echo "   SHA-256 : $(sha256sum "$ROLLBACK_ZIP" | awk '{print $1}')"
fi
echo "=================================================="