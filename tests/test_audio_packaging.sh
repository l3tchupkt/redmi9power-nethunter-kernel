#!/usr/bin/env bash
# ==============================================================================
# Test Suite 3: Audio Recovery Installer & Rollback Packager Validation
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
AUDIO_SCRIPT="$REPO_ROOT/scripts/package_audio_installer.sh"

echo "=================================================="
echo " [TEST 3/4] Testing Audio Recovery Packager & Safety"
echo "=================================================="

# Test Case A: Missing Source Rejection
echo "--- Running Subtest A: Missing source rejection ---"
if SRC_INSTALLER="/tmp/nonexistent_installer_$$" "$AUDIO_SCRIPT" >/dev/null 2>&1; then
    echo "  [FAIL] Expected failure on non-existent staging directory!" >&2
    exit 1
else
    echo "  [PASS] Properly rejected missing source staging directory."
fi

# Test Case B: WSA881x Exclusion Rejection
echo "--- Running Subtest B: WSA881x driver rejection ---"
TMP_STAGE="/tmp/test_wsa_check_$$"
mkdir -p "$TMP_STAGE/installer/audio_modules" "$TMP_STAGE/installer/META-INF/com/google/android" "$TMP_STAGE/rollback/META-INF/com/google/android" "$TMP_STAGE/out"
touch "$TMP_STAGE/installer/install.sh" "$TMP_STAGE/rollback/rollback.sh"
touch "$TMP_STAGE/installer/META-INF/com/google/android/update-binary"
touch "$TMP_STAGE/rollback/META-INF/com/google/android/update-binary"
# Inject banned wsa881x module
touch "$TMP_STAGE/installer/audio_modules/audio_wsa881x_analog.ko"

if SRC_INSTALLER="$TMP_STAGE/installer" SRC_ROLLBACK="$TMP_STAGE/rollback" OUT_DIR="$TMP_STAGE/out" "$AUDIO_SCRIPT" >/dev/null 2>&1; then
    echo "  [FAIL] Expected packager to reject disabled WSA881x module, but it passed!" >&2
    rm -rf "$TMP_STAGE"
    exit 1
else
    echo "  [PASS] Successfully rejected disabled reference WSA881x module."
fi
rm -rf "$TMP_STAGE"

# Test Case C: Raw Partition Image Rejection
echo "--- Running Subtest C: Raw backup image embedding rejection ---"
TMP_IMG_CHECK="/tmp/test_img_check_$$"
mkdir -p "$TMP_IMG_CHECK/installer/audio_modules" "$TMP_IMG_CHECK/installer/META-INF/com/google/android" "$TMP_IMG_CHECK/rollback/META-INF/com/google/android" "$TMP_IMG_CHECK/out"
touch "$TMP_IMG_CHECK/installer/install.sh" "$TMP_IMG_CHECK/rollback/rollback.sh"
touch "$TMP_IMG_CHECK/installer/META-INF/com/google/android/update-binary"
touch "$TMP_IMG_CHECK/rollback/META-INF/com/google/android/update-binary"
# Create 28 dummy ko files
for i in $(seq 1 28); do touch "$TMP_IMG_CHECK/installer/audio_modules/audio_mod_${i}.ko"; done
# Inject banned raw backup
touch "$TMP_IMG_CHECK/installer/vendor_backup.img"

if SRC_INSTALLER="$TMP_IMG_CHECK/installer" SRC_ROLLBACK="$TMP_IMG_CHECK/rollback" OUT_DIR="$TMP_IMG_CHECK/out" "$AUDIO_SCRIPT" >/dev/null 2>&1; then
    echo "  [FAIL] Expected packager to reject raw partition image (.img), but it passed!" >&2
    rm -rf "$TMP_IMG_CHECK"
    exit 1
else
    echo "  [PASS] Successfully prevented private raw vendor backup from being embedded."
fi
rm -rf "$TMP_IMG_CHECK"

# Test Case D: Actual Packaging with Verified Sources
if [ -d "$REPO_ROOT/../boot20/chime-audio-test" ] && [ -d "$REPO_ROOT/../boot20/chime-audio-rollback" ]; then
    echo "--- Running Subtest D: Packaging verified audio packages ---"
    TMP_OUT="/tmp/test_audio_out_$$"
    mkdir -p "$TMP_OUT"
    
    OUT_DIR="$TMP_OUT" "$AUDIO_SCRIPT" >/dev/null
    
    if [ ! -f "$TMP_OUT/chime-audio-test-v2.zip" ] || [ ! -f "$TMP_OUT/chime-audio-rollback-v2.zip" ]; then
        echo "  [FAIL] Audio ZIPs were not created!" >&2
        rm -rf "$TMP_OUT"
        exit 1
    fi
    
    # Assert no .img file in archives
    if unzip -l "$TMP_OUT/chime-audio-test-v2.zip" | grep -q "\.img" || unzip -l "$TMP_OUT/chime-audio-rollback-v2.zip" | grep -q "\.img"; then
        echo "  [FAIL] Created archive contains raw image!" >&2
        rm -rf "$TMP_OUT"
        exit 1
    fi
    
    echo "  [PASS] Verified audio installer and rollback ZIPs created and validated."
    rm -rf "$TMP_OUT"
fi

echo "=================================================="
echo " Audio Recovery Packager Test Suite PASSED 100%!"
echo "=================================================="