#!/usr/bin/env bash
# ==============================================================================
# Test Suite 4: Kernel Configuration Fragments Sanity Validation
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
CONFIGS_DIR="$REPO_ROOT/configs"

echo "=================================================="
echo " [TEST 4/4] Validating Configuration Fragments"
echo "=================================================="

FAILED=0

for cfg in vendor-fixes.config preempt-fixes.config nethunter-core.config; do
    file="$CONFIGS_DIR/$cfg"
    if [ ! -f "$file" ] || [ ! -s "$file" ]; then
        echo "  [FAIL] Config fragment $cfg missing or empty!" >&2
        FAILED=$((FAILED + 1))
        continue
    fi

    # Check for invalid Kconfig lines
    invalid_lines=$(grep -vE '^\s*#|^\s*$|^CONFIG_[A-Za-z0-9_]+=[ym0-9"]+|^# CONFIG_[A-Za-z0-9_]+ is not set' "$file" || true)
    if [ -n "$invalid_lines" ]; then
        echo "  [FAIL] Invalid Kconfig syntax in $cfg:" >&2
        echo "$invalid_lines" >&2
        FAILED=$((FAILED + 1))
    else
        echo "  [PASS] $cfg syntax is valid."
    fi
done

# Check that critical hardware/security options are declared
check_opt() {
    local opt="$1"
    local desc="$2"
    if grep -qE "^${opt}=y|^${opt}=m" "$CONFIGS_DIR"/*.config; then
        echo "  [PASS] Feature present: $desc ($opt)"
    else
        echo "  [FAIL] Missing required option: $opt ($desc)" >&2
        FAILED=$((FAILED + 1))
    fi
}

check_opt "CONFIG_HIDRAW" "BadUSB Raw HID Support"
check_opt "CONFIG_MAC80211" "Wireless Packet Injection Subsystem"
check_opt "CONFIG_USB_SERIAL_CP210X" "CP210X USB Serial / Hardware UART"
check_opt "CONFIG_USB_SERIAL_FTDI_SIO" "FTDI USB Serial / Hardware UART"
check_opt "CONFIG_USB_CONFIGFS_F_HID" "ConfigFS HID Gadget Emulation"
check_opt "CONFIG_PREEMPT" "ADSP Preemption Stability"
check_opt "CONFIG_SWITCH" "3.5mm Headset Jack Switch Driver"

echo "--------------------------------------------------"
if [ "$FAILED" -ne 0 ]; then
    echo " Configuration Fragment Test FAILED ($FAILED errors)!" >&2
    exit 1
fi
echo " Configuration Fragment Test Suite PASSED 100%!"
echo "=================================================="