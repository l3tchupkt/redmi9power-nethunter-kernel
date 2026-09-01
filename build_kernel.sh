#!/bin/bash
set -e

SRC_DIR="/home/letchu/lime-phase1/src"
OUT_DIR="/home/letchu/lime-phase1/out"
WORK_DIR="/mnt/e/MI9power/chime-nethunter-work"

export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=clang
export LLVM=1
export LLVM_IAS=1
export KBUILD_OUTPUT="$OUT_DIR"
export PATH="/usr/lib/llvm-19/bin:$PATH"
export KCFLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-function-pointer-types -Dmodule_assert_mutex=module_assert_mutex_or_preempt"

echo "--- CLEANING OUT DIRECTORY TO PREVENT ABI LEAKS ---"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "--- RESTORING BASE CONFIG ---"
cd "$SRC_DIR"
make O="$OUT_DIR" vendor/bengal-lite-perf_defconfig
scripts/kconfig/merge_config.sh -O "$OUT_DIR" "$OUT_DIR/.config" arch/arm64/configs/vendor/xiaomi/chime.config
scripts/kconfig/merge_config.sh -O "$OUT_DIR" "$OUT_DIR/.config" /tmp/phase1-fixes.config
make O="$OUT_DIR" olddefconfig

echo "--- APPLYING NETHUNTER PHASE 4 FRAGMENT (W/ UART) ---"
scripts/kconfig/merge_config.sh -m -O "$OUT_DIR" "$OUT_DIR/.config" /mnt/e/MI9power/chime-nethunter-work/nethunter-core.config
make O="$OUT_DIR" olddefconfig
make O="$OUT_DIR" syncconfig

echo "--- COMPILING PHASE 4 KERNEL ---"
make O="$OUT_DIR" -j$(nproc --all) KCFLAGS="$KCFLAGS" Image.gz dtbs

echo "--- REPACKING BOOT IMAGE v0.1.0 ---"
cd /mnt/e/MI9power/boot20
/mnt/e/MI9power/magiskboot-linux/magiskboot-linux-main/x86_64/magiskboot unpack test-patched.img
cp /home/letchu/lime-phase1/out/arch/arm64/boot/Image.gz kernel
/mnt/e/MI9power/magiskboot-linux/magiskboot-linux-main/x86_64/magiskboot repack test-patched.img nethunter-boot-v0.1.0.img
/mnt/e/MI9power/magiskboot-linux/magiskboot-linux-main/x86_64/magiskboot cleanup
echo "Done! Output is nethunter-boot-v0.1.0.img"

echo "--- COMPILING INTERNAL MODULES ---"
cd "$SRC_DIR"
make O="$OUT_DIR" -j$(nproc --all) KCFLAGS="$KCFLAGS" modules

echo "--- COMPILING INTERNAL WLAN (qcacld-3.0) ---"
cd "$SRC_DIR/drivers/staging/qcacld-3.0"
make KERNEL_SRC="$OUT_DIR" KCFLAGS="$KCFLAGS" -j$(nproc --all)
cp wlan.ko "$WORK_DIR/qca_cld3_wlan.ko"

echo "--- COMPILING REALTEK MODULES (Phase 3) ---"
cd "$WORK_DIR/rtl8188eus"
make clean
make KSRC="$OUT_DIR" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang -j$(nproc --all)

cd "$WORK_DIR/rtl8812au"
make clean
make KSRC="$OUT_DIR" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang -j$(nproc --all)

echo "PHASE 4 COMPILATION COMPLETE!"
