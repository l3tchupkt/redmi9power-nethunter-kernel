#!/usr/bin/env bash
# ==============================================================================
# Test Suite 2: Magisk Wireless Module Packager Validation
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
MAGISK_SCRIPT="$REPO_ROOT/build_magisk_module.sh"

echo "=================================================="
echo " [TEST 2/4] Testing Magisk Module Packaging & Safety"
echo "=================================================="

# Test Case A: Empty Module Failure Test
echo "--- Running Subtest A: Empty module rejection ---"
TMP_EMPTY_DIR="/tmp/test_nethunter_empty_$$"
mkdir -p "$TMP_EMPTY_DIR/out"

# Running with isolated empty dirs should fail with non-zero status
if OUT_DIR="$TMP_EMPTY_DIR/out" WORK_DIR="$TMP_EMPTY_DIR" "$MAGISK_SCRIPT" >/dev/null 2>&1; then
    echo "  [FAIL] Expected build_magisk_module.sh to fail on empty module set, but it succeeded!" >&2
    rm -rf "$TMP_EMPTY_DIR"
    exit 1
else
    echo "  [PASS] Properly rejected empty module set with non-zero exit code."
fi
rm -rf "$TMP_EMPTY_DIR"

# Test Case B: Dangerous Staging Path Rejection Test
echo "--- Running Subtest B: Dangerous directory rejection ---"
if STAGING_DIR="/" "$MAGISK_SCRIPT" >/dev/null 2>&1; then
    echo "  [FAIL] Expected rejection of STAGING_DIR=/, but it passed!" >&2
    exit 1
else
    echo "  [PASS] Successfully rejected dangerous target directory '/'."
fi

# Test Case C: Packaging Fixture Modules
echo "--- Running Subtest C: Packaging test fixture modules ---"
TMP_FIXTURE_DIR="/tmp/test_nethunter_fixture_$$"
mkdir -p "$TMP_FIXTURE_DIR/work" "$TMP_FIXTURE_DIR/out"

# Create valid AArch64 ELF dummy module fixture with 4.19 vermagic
create_dummy_ko() {
    local target="$1"
    # Write ELF Header (7f 45 4c 46 02 01 01 00 ... aarch64 machine 0xb7 0x00)
    printf '\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\xb7\x00' > "$target"
    # Append vermagic string
    printf '\x00vermagic=4.19.225-lilium-perf SMP preempt modversions aarch64\x00' >> "$target"
    # Pad to non-zero realistic size
    dd if=/dev/zero bs=1024 count=4 >> "$target" 2>/dev/null
}

create_dummy_ko "$TMP_FIXTURE_DIR/work/8188eu.ko"
create_dummy_ko "$TMP_FIXTURE_DIR/work/88XXau.ko"

OUT_DIR="$TMP_FIXTURE_DIR/out" WORK_DIR="$TMP_FIXTURE_DIR/work" STAGING_DIR="$TMP_FIXTURE_DIR/out/staging" "$MAGISK_SCRIPT" >/dev/null

TEST_ZIP="$TMP_FIXTURE_DIR/out/chime-nethunter-wireless-v0.1.0.zip"
if [ ! -f "$TEST_ZIP" ]; then
    echo "  [FAIL] Expected zip $TEST_ZIP was not created!" >&2
    rm -rf "$TMP_FIXTURE_DIR"
    exit 1
fi

# Verify ZIP structure
unzip -t -q "$TEST_ZIP"
echo "  [PASS] Generated ZIP structure verified via unzip -t."

# Verify module.prop contents
if ! unzip -p "$TEST_ZIP" module.prop | grep -q "id=chime-nethunter-wireless"; then
    echo "  [FAIL] module.prop missing expected module id!" >&2
    rm -rf "$TMP_FIXTURE_DIR"
    exit 1
fi
echo "  [PASS] module.prop contains correct id and metadata."

# Verify service.sh
if ! unzip -p "$TEST_ZIP" service.sh | grep -q "nethunter-modules.log"; then
    echo "  [FAIL] service.sh missing expected logging functionality!" >&2
    rm -rf "$TMP_FIXTURE_DIR"
    exit 1
fi
echo "  [PASS] service.sh contains hardened error logging."

# Verify modules inside zip
if ! unzip -l "$TEST_ZIP" | grep -q "system/vendor/lib/modules/8188eu.ko"; then
    echo "  [FAIL] 8188eu.ko not found in ZIP payload!" >&2
    rm -rf "$TMP_FIXTURE_DIR"
    exit 1
fi
if ! unzip -l "$TEST_ZIP" | grep -q "system/vendor/lib/modules/88XXau.ko"; then
    echo "  [FAIL] 88XXau.ko not found in ZIP payload!" >&2
    rm -rf "$TMP_FIXTURE_DIR"
    exit 1
fi
echo "  [PASS] Out-of-tree drivers staged accurately in ZIP."

rm -rf "$TMP_FIXTURE_DIR"
echo "=================================================="
echo " Magisk Packaging Test Suite PASSED 100%!"
echo "=================================================="