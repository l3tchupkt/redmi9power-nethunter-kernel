#!/usr/bin/env bash
# ==============================================================================
# Master Test Runner: Redmi 9 Power NetHunter Kernel Test Suite
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================================================"
echo " Starting NetHunter Kernel & Packaging Verification Test Suite"
echo " Time: $(date)"
echo " Root: $(cd "$SCRIPT_DIR/.." && pwd)"
echo "========================================================================"

FAILED_TESTS=()

run_suite() {
    local suite_name="$1"
    local script_path="$2"

    echo ""
    echo ">> Running $suite_name ($script_path)..."
    if bash "$script_path"; then
        echo ">> [SUCCESS] $suite_name completed without errors."
    else
        echo ">> [FAILURE] $suite_name failed!" >&2
        FAILED_TESTS+=("$suite_name")
    fi
}

run_suite "Suite 1: Shell Syntax Validation" "$SCRIPT_DIR/test_syntax.sh"
run_suite "Suite 2: Magisk Packaging & Rejection Checks" "$SCRIPT_DIR/test_magisk_packaging.sh"
run_suite "Suite 3: Audio Recovery Packaging & Exclusion Checks" "$SCRIPT_DIR/test_audio_packaging.sh"
run_suite "Suite 4: Kernel Config Fragments Sanity" "$SCRIPT_DIR/test_configs.sh"

echo ""
echo "========================================================================"
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo " ALL TEST SUITES PASSED (4/4 passed - 100% success)"
    echo "========================================================================"
    exit 0
else
    echo " SOME TEST SUITES FAILED (${#FAILED_TESTS[@]} failed):" >&2
    for t in "${FAILED_TESTS[@]}"; do
        echo "   - $t" >&2
    done
    echo "========================================================================"
    exit 1
fi
