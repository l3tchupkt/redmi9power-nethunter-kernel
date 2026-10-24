#!/usr/bin/env bash
# ==============================================================================
# Kali NetHunter Kernel Build Pipeline for Xiaomi Redmi 9 Power / Poco M3
# Target: Qualcomm SM6115 (Bengal / Snapdragon 662) - Linux 4.19
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Configurable paths with user override support
SRC_DIR="${SRC_DIR:-}"
if [ -z "$SRC_DIR" ]; then
    if [ -d "$REPO_ROOT/../kernel_xiaomi_chime/kernel_xiaomi_chime" ]; then
        SRC_DIR="$(cd "$REPO_ROOT/../kernel_xiaomi_chime/kernel_xiaomi_chime" && pwd)"
    elif [ -d "${HOME:-}/lime-phase1/src" ]; then
        SRC_DIR="${HOME}/lime-phase1/src"
    else
        echo "ERROR: Kernel source directory not found." >&2
        echo "Please specify via: export SRC_DIR=/path/to/kernel_source" >&2
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

# Modern LLVM/Clang compiler compatibility flags
export KCFLAGS="${KCFLAGS:--Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-function-pointer-types -Dmodule_assert_mutex=module_assert_mutex_or_preempt}"

echo "=================================================="
echo " Kali NetHunter Kernel Build Pipeline"
echo " Target Device    : Xiaomi chime/lime/citrus (SM6115)"
echo " Source Directory : $SRC_DIR"
echo " Output Directory : $OUT_DIR"
echo " Configs Directory: $CONFIGS_DIR"
echo " Parallel Jobs    : $JOBS"
echo " Clean Build Mode : $CLEAN_BUILD"
echo "=================================================="

# --- Pre-flight Checks ---
if [ ! -f "$SRC_DIR/Makefile" ] || [ ! -f "$SRC_DIR/Kconfig" ]; then
    echo "ERROR: Invalid kernel source tree in $SRC_DIR" >&2
    exit 1
fi

if ! command -v "$CC" >/dev/null 2>&1; then
    for llvm_path in /usr/lib/llvm-19/bin /usr/lib/llvm-18/bin /usr/lib/llvm-17/bin; do
        if [ -x "$llvm_path/clang" ]; then
            export PATH="$llvm_path:$PATH"
            break
        fi
    done
    if ! command -v "$CC" >/dev/null 2>&1; then
        echo "ERROR: Clang compiler '$CC' not found in PATH." >&2
        exit 1
    fi
fi

CC_VERSION=$("$CC" --version 2>/dev/null | head -n1 || echo "unknown")
echo " Compiler Detected: $CC_VERSION"

# Validate required configuration fragments
for cfg in vendor-fixes.config preempt-fixes.config nethunter-core.config; do
    if [ ! -f "$CONFIGS_DIR/$cfg" ]; then
        echo "ERROR: Required configuration fragment $CONFIGS_DIR/$cfg is missing!" >&2
        exit 1
    fi
done

CHIME_CFG="$SRC_DIR/arch/arm64/configs/vendor/xiaomi/chime.config"
if [ ! -f "$CHIME_CFG" ]; then
    echo "ERROR: Xiaomi Chime device config missing: $CHIME_CFG" >&2
    exit 1
fi

# Safe Clean Build Handling
if [ "$CLEAN_BUILD" -eq 1 ]; then
    case "$OUT_DIR" in
        ""|"/"|"/root"|"/home"|"$HOME"|"$SRC_DIR"|"$REPO_ROOT")
            echo "FATAL: Dangerous clean path rejected: '$OUT_DIR'" >&2
            exit 1
            ;;
    esac
    echo "--- [Clean Build] Removing previous output: $OUT_DIR ---"
    rm -rf "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

START_TIME=$(date +%s)

# --- Deterministic Configuration Merge ---
echo "--- [1/5] Applying Base Qualcomm Bengal Defconfig ---"
cd "$SRC_DIR"
make O="$OUT_DIR" vendor/bengal-lite-perf_defconfig

echo "--- [2/5] Merging Xiaomi Chime Hardware Profile ---"
"$SRC_DIR/scripts/kconfig/merge_config.sh" -O "$OUT_DIR" "$OUT_DIR/.config" "$CHIME_CFG"

echo "--- [3/5] Merging Vendor & ADSP Preemption Stability Fixes ---"
"$SRC_DIR/scripts/kconfig/merge_config.sh" -O "$OUT_DIR" "$OUT_DIR/.config" \
    "$CONFIGS_DIR/vendor-fixes.config" \
    "$CONFIGS_DIR/preempt-fixes.config"

echo "--- [4/5] Merging NetHunter Core Hardware & Security Fragment ---"
"$SRC_DIR/scripts/kconfig/merge_config.sh" -m -O "$OUT_DIR" "$OUT_DIR/.config" \
    "$CONFIGS_DIR/nethunter-core.config"

make O="$OUT_DIR" olddefconfig
make O="$OUT_DIR" syncconfig

# --- Kernel & Module Compilation ---
echo "--- [5/5] Compiling Kernel Image, DTBs, and Modules ---"
make O="$OUT_DIR" -j"$JOBS" KCFLAGS="$KCFLAGS" Image.gz dtbs modules

# --- Compile Qualcomm Internal WLAN Module (qcacld-3.0) ---
if [ -d "$SRC_DIR/drivers/staging/qcacld-3.0" ]; then
    echo "--- Compiling Internal WLAN Driver (qcacld-3.0) ---"
    cd "$SRC_DIR/drivers/staging/qcacld-3.0"
    make KERNEL_SRC="$OUT_DIR" KCFLAGS="$KCFLAGS" -j"$JOBS"
    mkdir -p "$OUT_DIR/modules"
    cp wlan.ko "$OUT_DIR/modules/qca_cld3_wlan.ko"
    echo "Staged qca_cld3_wlan.ko -> $OUT_DIR/modules/"
fi

# --- Compile Out-of-tree Realtek Drivers (if trees present) ---
if [ -d "$WORK_DIR/rtl8188eus" ]; then
    echo "--- Compiling RTL8188EUS Driver ---"
    cd "$WORK_DIR/rtl8188eus"
    make clean || true
    make KSRC="$OUT_DIR" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" CC="$CC" -j"$JOBS"
    mkdir -p "$OUT_DIR/modules"
    find . -name '8188eu.ko' -exec cp {} "$OUT_DIR/modules/" \; 2>/dev/null || true
fi

if [ -d "$WORK_DIR/rtl8812au" ]; then
    echo "--- Compiling RTL8812AU Driver ---"
    cd "$WORK_DIR/rtl8812au"
    make clean || true
    make KSRC="$OUT_DIR" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" CC="$CC" -j"$JOBS"
    mkdir -p "$OUT_DIR/modules"
    find . -name '88XXau.ko' -o -name '8812au.ko' -exec cp {} "$OUT_DIR/modules/" \; 2>/dev/null || true
fi

# --- Validation of Generated Artifacts ---
IMAGE_PATH="$OUT_DIR/arch/arm64/boot/Image.gz"
if [ ! -f "$IMAGE_PATH" ] || [ ! -s "$IMAGE_PATH" ]; then
    echo "ERROR: Kernel image $IMAGE_PATH was not generated or is 0 bytes!" >&2
    exit 1
fi

DTB_COUNT=$(find "$OUT_DIR/arch/arm64/boot/dts/vendor/qcom" -name "*.dtb" 2>/dev/null | wc -l || echo 0)
if [ "$DTB_COUNT" -eq 0 ]; then
    echo "ERROR: No device tree blobs (.dtb) were generated in $OUT_DIR!" >&2
    exit 1
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# --- Generate Build Manifest ---
MANIFEST_FILE="$OUT_DIR/build_manifest.json"
KERNEL_REV="unknown"
if [ -d "$SRC_DIR/.git" ] && command -v git >/dev/null 2>&1; then
    KERNEL_REV=$(git -C "$SRC_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
fi

cat <<EOF > "$MANIFEST_FILE"
{
  "build_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "build_duration_seconds": $ELAPSED,
  "target_device": "Xiaomi chime/lime/citrus (Qualcomm SM6115)",
  "kernel_source_revision": "$KERNEL_REV",
  "compiler": "$CC_VERSION",
  "cross_compile": "$CROSS_COMPILE",
  "configs": {
    "vendor_fixes_sha256": "$(sha256sum "$CONFIGS_DIR/vendor-fixes.config" | awk '{print $1}')",
    "preempt_fixes_sha256": "$(sha256sum "$CONFIGS_DIR/preempt-fixes.config" | awk '{print $1}')",
    "nethunter_core_sha256": "$(sha256sum "$CONFIGS_DIR/nethunter-core.config" | awk '{print $1}')"
  },
  "artifacts": {
    "kernel_image": {
      "path": "arch/arm64/boot/Image.gz",
      "size_bytes": $(stat -c%s "$IMAGE_PATH" 2>/dev/null || wc -c < "$IMAGE_PATH"),
      "sha256": "$(sha256sum "$IMAGE_PATH" | awk '{print $1}')"
    },
    "dtb_count": $DTB_COUNT
  }
}
EOF

echo "=================================================="
echo " BUILD COMPLETED SUCCESSFULLY in ${ELAPSED}s"
echo " Kernel Image   : $IMAGE_PATH ($(stat -c%s "$IMAGE_PATH" 2>/dev/null || wc -c < "$IMAGE_PATH") bytes)"
echo " DTBs Generated : $DTB_COUNT"
echo " Build Manifest : $MANIFEST_FILE"
echo "=================================================="