# Kali NetHunter Kernel for Xiaomi Redmi 9 Power / Poco M3 (Chime / Lime / Citrus)

**Kernel Version:** `4.19.225-lilium-perf` (NetHunter Edition)  
**Author:** `@l3tchupkt`  
**SoC:** Qualcomm Snapdragon 662 (Bengal / SM6115)  
**Target ROM:** Android 13 (LineageOS 20)  
**Target Architecture:** ARM64 (`aarch64`)

A production-tested, bare-metal Kali NetHunter kernel for the Xiaomi Redmi 9 Power / Poco M3. Engineered for physical penetration testing, hardware hacking, out-of-tree Wi-Fi packet injection, BadUSB HID attacks, hardware UART debugging, and RTL-SDR spectrum analysis with verified hardware audio output.

---

## ⚡ Verified Feature Status Matrix

We explicitly distinguish between features verified through hands-on hardware testing, features enabled in kernel configuration, and unverified items:

| Subsystem / Feature | Driver / Implementation | Status | Verification Evidence |
| :--- | :--- | :--- | :--- |
| **Internal Audio Subsystem** | Qualcomm Bengal ASoC + Awinic PA (`aw87359`/`aw87519`) | **VERIFIED WORKING** | `bengal-idp-snd-card` registered, 31 PCMs active, speaker & 3.5mm headset jack output verified |
| **Packet Injection & Monitor Mode** | `mac80211` subsystem + Realtek out-of-tree drivers | **VERIFIED WORKING** | RTL8812AU (AC600) and RTL8188EUS (TL-WN722N) monitor mode & injection functional |
| **RTL-SDR Spectrum Analysis** | DWC3 USB Host + Realtek RTL2832U / R820T2 | **VERIFIED WORKING** | `rtl_test -t` pass in NetHunter, RF Analyzer active, SDR++ streaming with audio sink |
| **Hardware UART / Serial Debugging** | Built-in `CP210X`, `FTDI_SIO`, `CH341`, `PL2303` | **VERIFIED WORKING** | Device nodes appear under `/dev/ttyUSB0`, serial communications verified |
| **BadUSB / HID Keyboard Emulation** | Raw HID (`CONFIG_HIDRAW=y`) + ConfigFS USB gadget | **VERIFIED WORKING** | Device node `/dev/hidg0` active, keystroke payload injection verified |
| **USB Host / OTG Interface** | Qualcomm DWC3 USB Host Controller | **VERIFIED WORKING** | USB enumeration verified with keyboards, SDR dongles, Wi-Fi adapters, and hubs |
| **Wireless Debugging** | ADB over TCP/IP (`adb tcpip 5555`) | **VERIFIED WORKING** | Remote logging (`dmesg -w`, `logcat`) verified while OTG port is occupied |
| **Generic USB Bluetooth Dongles** | `CONFIG_BT_HCIBTUSB=y`, `CONFIG_BT_HCIUART=y` | *Inferred from Config* | Built into kernel; awaiting dedicated external BT dongle bench test |
| **Ralink / Atheros USB Wi-Fi** | `RT2800USB=m`, `ATH9K_HTC=m` | *Inferred from Config* | Kernel config fragments enabled; primary focus maintained on Realtek adapters |

---

## 🛠️ Required Assets & Hardware Prerequisites

### Software Requirements:
- [Android SDK Platform-Tools (ADB & Fastboot)](https://developer.android.com/tools/releases/platform-tools)
- **Custom Recovery:** [OrangeFox Recovery R12.0 Unofficial for Chime](https://sourceforge.net/projects/joes-android-builds/files/recovery/OrangeFox-R12.0_14-Unofficial-chime.zip/download)
- **Custom ROM:** [LineageOS 20 (Android 13) for Chime](https://sourceforge.net/projects/joes-android-builds/files/LineageOS/20/)
- [Magisk App](https://github.com/topjohnwu/Magisk) (for root access and wireless module loading)
- [Kali NetHunter Store App](https://store.nethunter.com/) (NetHunter App, Terminal, and Chroot Manager)

### Crucial Hardware Requirement:
- **OTG Y-Cable or Powered USB Hub:** *(Mandatory for high-power external Wi-Fi adapters like the AC600. See hardware limitations below).*

---

## 🚀 Installation Guide

### Step 0: Recovery & Base ROM Setup
1. Ensure your bootloader is unlocked.
2. Flash **OrangeFox Recovery R12.0** to your device.
3. Perform a clean flash of **LineageOS 20**.
4. Flash **Magisk** via OrangeFox to obtain root access, then boot into the system.

### Step 1: Flash the NetHunter Kernel
1. Reboot the phone into **Fastboot mode** (Power off, hold Volume Down + Power).
2. Connect the phone to your PC via USB cable.
3. Flash the custom kernel boot image:
   ```bash
   fastboot flash boot nethunter-boot.img
   fastboot reboot
   ```

### Step 2: Install Wireless Modules (Magisk)
1. Transfer `chime-nethunter-modules-v0.1.0.zip` to the phone's internal storage.
2. Open the **Magisk App** -> **Modules** tab -> **Install from storage**.
3. Select `chime-nethunter-modules-v0.1.0.zip` and tap **Reboot** once finished.

### Step 3: Install Audio Subsystem Package (Recovery)
To guarantee working internal speakers, headset jack, and ALSA registration:
1. Transfer `chime-audio-test-v2.zip` to your phone's storage (`/sdcard/`).
2. Reboot into **OrangeFox Recovery**.
3. Tap **Install** -> Select `chime-audio-test-v2.zip` -> Swipe to Confirm.
4. Verify all 8 preflight and installation checks pass with exit status `0`.
5. Reboot to system. Verify sound card registration via `cat /proc/asound/cards`.

### Step 4: Install Kali NetHunter Chroot
1. Install the **NetHunter Store App**, then install **NetHunter** and **NetHunter Terminal**.
2. Open the **NetHunter App**, grant root permissions, navigate to **Kali Chroot Manager**, and install the Kali chroot.

---

## ⚠️ Important Hardware Nuances & Quirk Notes

### 1. The Qualcomm PMIC 1.5A Inrush Limit
The Power Management IC on the Redmi 9 Power limits OTG current output to **1.5A (1500mA)** (`qcom,otg-cl-ua = MICRO_1P5A`). High-gain Wi-Fi adapters (such as Alfa AC600) draw heavy inrush current on radio initialization, which trips the PMIC Over Current Protection (OCP) and shuts off the USB port.  
**Fix:** Always use an **OTG Y-Cable** with an external 5V power bank for external Wi-Fi adapters.

### 2. RTL8812AU Monitor Mode Quirk
The Realtek RTL8812AU driver rejects virtual monitor interfaces created by `airmon-ng start wlan1` (returns error `-95`). You must set the physical interface into monitor mode directly:
```bash
ifconfig wlan1 down
iw dev wlan1 set type monitor
ifconfig wlan1 up
airodump-ng wlan1
```

### 3. SDR++ Cold-Start Requirement
SDR++ on Android queries USB devices and requests permissions **only during `MainActivity.onCreate()`**. It lacks a dynamic hotplug receiver.  
**Rule:** Always plug in your RTL-SDR via OTG **before** launching SDR++. If it was already open, force-stop it (`am force-stop org.sdrpp.sdrpp`) and relaunch.

---

## 📚 Deep-Dive Technical Documentation

Detailed architecture and engineering guides are located in the [`docs/`](docs/) directory:

- 📖 [**Audio Subsystem Repair & Architecture**](docs/AUDIO_REPAIR.md) — Diagnosis of missing ALSA card, Hexagon DSP PIL boot timing, kernel ABI audit, WSA881x exclusion, and atomic recovery installer/rollback mechanics.
- 📡 [**RTL-SDR Integration & Software Defined Radio**](docs/SDR_SETUP.md) — USB permissions, NetHunter chroot `rtl_test`, RF Analyzer setup, SDR++ direct USB vs RTL-TCP daemon, and audio sink routing.
- 🔌 [**Hardware Hacking, Wireless Injection & USB Gadget**](docs/HARDWARE_AND_WIRELESS.md) — RTL8812AU/RTL8188EUS packet injection, BadUSB `/dev/hidg0`, hardware UART `/dev/ttyUSB0`, and wireless ADB debugging.
- ⚙️ [**Kernel Compilation & Reproducible Build Guide**](docs/BUILD_GUIDE.md) — Toolchain requirements (LLVM 19, Clang, AArch64 GCC), configuration fragments, out-of-tree module compilation, and boot image repacking.

---

## 🔒 Safety & Recovery Hierarchy

- **Raw Vendor Backup:** Preserved at `/data/local/tmp/vendor_backup.img` on device and host (SHA-256: `6b4f31af379b479f04c04a29c1f92be44163c95c6e67b9bf9c4a436045c9843c`). Never overwrite or delete this file.
- **Audio Rollback Package:** `chime-audio-rollback-v2.zip` (SHA-256: `00805e9b9b9f0368ea87f6bf84d03f86e00107eccb5e7cbe4e2878793e25d03e`). Flashed via OrangeFox to restore factory stock audio modules and `modules.dep`.

---

## 🔗 Upstream Sources & Credits
- **Kernel Base Source:** [LineageOS SM6115 / Bengal Kernel (Linux 4.19)](https://github.com/LineageOS/android_kernel_xiaomi_sm6115)
- **Device Kernel Tree:** [Lilium Project kernel_xiaomi_chime (ursinia)](https://github.com/liliumproject/kernel_xiaomi_chime)
- **RTL8188EUS Driver Source:** [aircrack-ng/rtl8188eus](https://github.com/aircrack-ng/rtl8188eus)
- **RTL8812AU Driver Source:** [aircrack-ng/rtl8812au](https://github.com/aircrack-ng/rtl8812au)
- **NetHunter Installer & Core:** [Offsec NetHunter Devices](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-devices)