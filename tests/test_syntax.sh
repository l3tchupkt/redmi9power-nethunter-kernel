#!/usr/bin/env bash
# ==============================================================================
# Test Suite 1: Shell Script Syntax Validation (bash -n)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

echo "=================================================="
echo " [TEST 1/4] Validating Shell Syntax Across Repository"
echo "=================================================="

FAILED=0
TESTED=0

while IFS= read -r script; do
    TESTED=$((TESTED + 1))
    if bash -n "$script"; then
        echo "  [PASS] $script"
    else
        echo "  [FAIL] Syntax error in $script" >&2
        FAILED=$((FAILED + 1))
    fi
done < <(find "$REPO_ROOT" -maxdepth 3 -name "*.sh" -not -path "*/.git/*" -not -path "*/out/*" -not -path "*/staging/*")

echo "--------------------------------------------------"
echo " Syntax Test Results: $TESTED tested, $FAILED failed."
if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
echo "=================================================="