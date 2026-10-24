#!/usr/bin/env bash
# ==============================================================================
# Kali NetHunter Kernel Build Script for Xiaomi Redmi 9 Power / Poco M3 (lime/chime)
# Target: Snapdragon 662 (Bengal / SM6115) - Linux 4.19
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Configurable paths with sensible fallbacks
SRC_DIR="${SRC_DIR:-}"
if [ -z "$SRC_DIR" ]; then
    if [ -d "$REPO_ROOT/../kernel_xiaomi_chime/kernel_xiaomi_chime" ]; then
        SRC_DIR="$(cd "$REPO_ROOT/../kernel_xiaomi_chime/kernel_xiaomi_chime" && pwd)"
    elif [ -d "${HOME:-}/lime-phase1/src" ]; then
        SRC_DIR="${HOME}/lime-phase1/src"
    else
        echo "ERROR: Kernel source directory not found."
        echo "Please export SRC_DIR=/path/to/kernel_source before running."
        exit 1
    fi
fi

OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"
CONFIGS_DIR="${CONFIGS_DIR:-$REPO_ROOT/configs}"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/../chime-nethunter-work}"
CLEAN_BUILD="${CLEAN_BUILD:-0}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

export ARCH="${ARCH:-arm64}"
export SUBARCH="${SUBARCH:-arm64}"
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
export CC="${CC:-clang}"
export LLVM="${LLVM:-1}"
export LLVM_IAS="${LLVM_IAS:-1}"
export KBUILD_OUTPUT="$OUT_DIR"

# Compiler flags for modern LLVM/Clang toolchains
export KCFLAGS="${KCFLAGS:--Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-function-pointer-types -Dmodule_assert_mutex=module_assert_mutex_or_preempt}"

echo "=================================================="
echo " Kali NetHunter Kernel Builder — Xiaomi Chime/Lime"
echo "=================================================="
echo " Source Directory : $SRC_DIR"
echo " Output Directory : $OUT_DIR"
echo " Configs Directory: $CONFIGS_DIR"
echo " Compiler (CC)    : $CC ($($CC --version 2>/dev/null | head -n1 || echo 'unknown'))"
echo " Cross Compiler   : $CROSS_COMPILE"
echo " Parallel Jobs    : $JOBS"
echo " Clean Build      : $CLEAN_BUILD"
echo "=================================================="

# --- Pre-flight Checks ---
if [ ! -f "$SRC_DIR/Makefile" ] || [ ! -f "$SRC_DIR/Kconfig" ]; then
    echo "ERROR: Invalid kernel source tree in $SRC_DIR"
    exit 1
fi

if ! command -v "$CC" >/dev/null 2>&1; then
    # Try finding LLVM in standard Debian/Ubuntu locations
    for llvm_path in /usr/lib/llvm-19/bin /usr/lib/llvm-18/bin /usr/lib/llvm-17/bin; do
        if [ -x "$llvm_path/clang" ]; then
            export PATH="$llvm_path:$PATH"
            break
        fi
    done
    if ! command -v "$CC" >/dev/null 2>&1; then
        echo "ERROR: Clang compiler '$CC' not found in PATH."
        exit 1
    fi
fi

for cfg in vendor-fixes.config preempt-fixes.config nethunter-core.config; do
    if [ ! -f "$CONFIGS_DIR/$cfg" ]; then
        echo "ERROR: Required config fragment $CONFIGS_DIR/$cfg missing!"
        exit 1
    fi
done

# Safe clean handling
if [ "$CLEAN_BUILD" -eq 1 ]; then
    if [ "$OUT_DIR" = "/" ] || [ "$OUT_DIR" = "$HOME" ] || [ "$OUT_DIR" = "$SRC_DIR" ]; then
        echo "FATAL: Refusing to clean unsafe OUT_DIR path: '$OUT_DIR'"
        exit 1
    fi
    echo "--- Cleaning output directory: $OUT_DIR ---"
    rm -rf "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

# --- Kernel Configuration ---
echo "--- [1/5] Generating Base Defconfig ---"
cd "$SRC_DIR"
make O="$OUT_DIR" vendor/bengal-lite-perf_defconfig

echo "--- [2/5] Merging Xiaomi Chime Hardware Config ---"
"$SRC_DIR/scripts/kconfig/merge_config.sh" -O "$OUT_DIR" "$OUT_DIR/.config" \
    "$SRC_DIR/arch/arm64/configs/vendor/xiaomi/chime.config"

echo "--- [3/5] Merging Vendor & Preemption Fixes ---"
"$SRC_DIR/scripts/kconfig/merge_config.sh" -O "$OUT_DIR" "$OUT_DIR/.config" \
    "$CONFIGS_DIR/vendor-fixes.config" \
    "$CONFIGS_DIR/preempt-fixes.config"

echo "--- [4/5] Merging NetHunter Core & Hardware Drivers ---"
"$SRC_DIR/scripts/kconfig/merge_config.sh" -m -O "$OUT_DIR" "$OUT_DIR/.config" \
    "$CONFIGS_DIR/nethunter-core.config"

make O="$OUT_DIR" olddefconfig
make O="$OUT_DIR" syncconfig

# --- Kernel Compilation ---
echo "--- [5/5] Compiling Kernel Image & DTBs ---"
make O="$OUT_DIR" -j"$JOBS" KCFLAGS="$KCFLAGS" Image.gz dtbs modules

echo "--- Compiling Internal WLAN (qcacld-3.0) ---"
if [ -d "$SRC_DIR/drivers/staging/qcacld-3.0" ]; then
    cd "$SRC_DIR/drivers/staging/qcacld-3.0"
    make KERNEL_SRC="$OUT_DIR" KCFLAGS="$KCFLAGS" -j"$JOBS"
    mkdir -p "$OUT_DIR/modules"
    cp wlan.ko "$OUT_DIR/modules/qca_cld3_wlan.ko"
    echo "Staged qca_cld3_wlan.ko -> $OUT_DIR/modules/"
fi

# Out-of-tree Realtek drivers
if [ -d "$WORK_DIR/rtl8188eus" ]; then
    echo "--- Compiling RTL8188EUS Driver ---"
    cd "$WORK_DIR/rtl8188eus"
    make clean || true
    make KSRC="$OUT_DIR" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" CC="$CC" -j"$JOBS"
    find . -name '8188eu.ko' -exec cp {} "$OUT_DIR/modules/" \; 2>/dev/null || true
fi

if [ -d "$WORK_DIR/rtl8812au" ]; then
    echo "--- Compiling RTL8812AU Driver ---"
    cd "$WORK_DIR/rtl8812au"
    make clean || true
    make KSRC="$OUT_DIR" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" CC="$CC" -j"$JOBS"
    find . -name '88XXau.ko' -o -name '8812au.ko' -exec cp {} "$OUT_DIR/modules/" \; 2>/dev/null || true
fi

echo "=================================================="
echo " BUILD COMPLETED SUCCESSFULLY!"
echo " Kernel Image: $OUT_DIR/arch/arm64/boot/Image.gz"
echo " DTB Files   : $OUT_DIR/arch/arm64/boot/dts/vendor/qcom/"
if [ -d "$OUT_DIR/modules" ]; then
    echo " Built Modules:"
    ls -lh "$OUT_DIR/modules"/*.ko 2>/dev/null || true
fi
echo "=================================================="