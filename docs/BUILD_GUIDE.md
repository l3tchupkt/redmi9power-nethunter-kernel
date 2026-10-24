# NetHunter Kernel Reproducible Build & Compilation Guide

**Target Device:** Xiaomi Redmi 9 Power / Poco M3 (`chime/lime/citrus`)  
**Architecture:** ARM64 (`aarch64`)  
**Kernel Version:** Linux 4.19 (Qualcomm Bengal SM6115)  
**Host Environment:** Ubuntu 22.04 LTS / Debian 12 / WSL2  

---

## 1. Toolchain & Host Dependencies

Building this kernel requires Clang (LLVM 17–19 recommended) and an AArch64 GNU cross-compiler:

```bash
sudo apt update && sudo apt install -y \
    build-essential \
    bc \
    bison \
    flex \
    libncurses-dev \
    libssl-dev \
    libelf-dev \
    clang-19 \
    lld-19 \
    llvm-19 \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    git \
    zip \
    unzip \
    device-tree-compiler
```

---

## 2. Directory Structure & Source Setup

The recommended directory layout for reproducible builds:

```text
workspace/
├── kernel_source/                  # Upstream Lilium / LineageOS 4.19 kernel
│   ├── arch/arm64/configs/...
│   ├── drivers/staging/qcacld-3.0/
│   └── Makefile
├── redmi9power-nethunter-kernel/   # This repository
│   ├── build_kernel.sh
│   ├── build_magisk_module.sh
│   ├── configs/
│   │   ├── vendor-fixes.config
│   │   ├── preempt-fixes.config
│   │   └── nethunter-core.config
│   ├── docs/
│   └── scripts/
└── chime-nethunter-work/           # Out-of-tree wireless driver repositories
    ├── rtl8188eus/
    └── rtl8812au/
```

Clone the upstream kernel source:
```bash
git clone https://github.com/liliumproject/kernel_xiaomi_chime.git -b ursinia kernel_source
```

---

## 3. Configuration Fragment Breakdown

The build pipeline constructs a unified kernel configuration by merging four discrete layers:

1. **Base Defconfig:** `vendor/bengal-lite-perf_defconfig` (Qualcomm reference Bengal).
2. **Device Hardware Defconfig:** `arch/arm64/configs/vendor/xiaomi/chime.config` (Xiaomi display, camera, sensors, audio topology).
3. **Vendor Compilation Fixes (`configs/vendor-fixes.config`):**
   - Disables duplicate generic Novatek `NT36XXX` and FocalTech `FTS` touchscreen drivers to resolve LLD linker conflicts with device-specific `NT36672A` and `FT8719` drivers.
   - Enables `CONFIG_SWITCH=y` to resolve `wcd-mbhc-v2.c` vendor typo and support the 3.5mm headset jack.
   - Enables `CONFIG_HQ_SYSFS_SUPPORT=y` for Xiaomi hardware sysfs registration.
   - Disables `CONFIG_DEBUG_FS` to bypass msm_bus adhoc tracepoint linking issues.
4. **Preemption Architecture Fix (`configs/preempt-fixes.config`):**
   - Enforces `CONFIG_PREEMPT=y` (standard preemption) instead of `CONFIG_PREEMPT_RT` to maintain stability during Hexagon ADSP Peripheral Image Loader (PIL) initialization.
5. **NetHunter Core Fragment (`configs/nethunter-core.config`):**
   - Enables `mac80211` wireless injection subsystem.
   - Enables raw HID (`CONFIG_HIDRAW=y`) and USB ConfigFS endpoints for BadUSB.
   - Compiles native USB-to-serial hardware drivers (`CP210X`, `FTDI_SIO`, `CH341`, `PL2303`).

---

## 4. Building the Kernel

To run the automated build pipeline:

```bash
cd redmi9power-nethunter-kernel

# Define source location if not in default relative directory
export SRC_DIR=/path/to/kernel_source

# Launch the build
./build_kernel.sh
```

### Build Outputs:
Upon completion, the build script generates artifacts in `out/`:
- `out/arch/arm64/boot/Image.gz` — Unpacked compressed kernel binary.
- `out/arch/arm64/boot/dts/vendor/qcom/` — Compiled device tree blobs (`.dtb`).
- `out/modules/qca_cld3_wlan.ko` — Rebuilt internal Qualcomm Wi-Fi driver.
- `out/modules/8188eu.ko`, `out/modules/88XXau.ko` — Compiled Realtek wireless injection drivers.

---

## 5. Boot Image Packaging with Magiskboot

To inject the compiled kernel (`Image.gz`) into an existing stock LineageOS boot image:

```bash
# 1. Unpack existing working boot image
magiskboot unpack boot.img

# 2. Replace the kernel binary
cp out/arch/arm64/boot/Image.gz kernel

# 3. Repack the boot image
magiskboot repack boot.img nethunter-boot.img

# 4. Clean up temporary unpacking files
magiskboot cleanup
```

---

## 6. Packaging Wireless Modules (Magisk)

To package the out-of-tree wireless drivers into a flashable Magisk module:

```bash
./build_magisk_module.sh
```
This produces `out/chime-nethunter-wireless-v0.1.0.zip` ready for installation via the Magisk App.

---

## 7. Packaging Audio Subsystem Recovery Packages

To rebuild the tested recovery installer and rollback packages:

```bash
./scripts/package_audio_installer.sh
```
Generates `out/chime-audio-test-v2.zip` and `out/chime-audio-rollback-v2.zip` with verified SHA-256 signatures.

---

## 8. Running Automated Verification Test Suites

To verify script syntax, packaging logic, error handling, and configuration integrity without physical hardware:

```bash
bash tests/run_all_tests.sh
```

### Test Coverage:
1. **Shell Syntax (`tests/test_syntax.sh`):** Validates all shell scripts in the repository using `bash -n`.
2. **Magisk Packaging (`tests/test_magisk_packaging.sh`):** Verifies rejection of empty module sets, rejection of dangerous staging paths (`/`), fixture module packaging, and payload integrity (`unzip -t`).
3. **Audio Recovery Packaging (`tests/test_audio_packaging.sh`):** Ensures source directories exist, verifies exclusion of disabled reference WSA881x drivers, verifies strict prevention of raw partition images (`.img`) from being bundled, and checks ZIP generation.
4. **Configuration Fragments (`tests/test_configs.sh`):** Confirms valid Kconfig syntax across all `.config` fragments and asserts required security/hardware features (`CONFIG_HIDRAW`, `CONFIG_MAC80211`, `CONFIG_USB_SERIAL_*`, `CONFIG_USB_CONFIGFS_F_HID`, `CONFIG_PREEMPT`, `CONFIG_SWITCH`).

### ⚠️ Verification Boundaries & Non-Goals:
- **Packaging Logic vs. Driver Compatibility:** Synthetic fixture files in `test_magisk_packaging.sh` test *packager error handling, path traversal guards, and archive creation*. They do **not** validate binary ABI compatibility, symbol resolution against `Module.symvers`, or driver loading in the Android kernel.
- **Static Fragment Linting vs. Runtime Enablers:** `test_configs.sh` confirms option strings are declared in configuration fragments. It does **not** prove that Kconfig dependency chains resolve without conflict during `make olddefconfig`, that the kernel compiles, or that features function at runtime.
- **Host Testing vs. Device Verification:** Automated host-side test suites do **not** substitute for physical bench testing of boot, audio playback, USB HID keystroke injection, UART communications, or Wi-Fi packet injection on actual hardware.