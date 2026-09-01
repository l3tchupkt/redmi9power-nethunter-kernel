# Kali NetHunter Kernel for Redmi 9 Power (Chime/Lime/Citrus)
**Version**: `v0.1.0`
**Author**: `@l3tchupkt`
**Device**: Xiaomi Redmi 9 Power / Poco M3 (Snapdragon 662)
**OS Base**: Android 13 (LineageOS 20) / Linux 4.19

A custom, bare-metal Kali NetHunter kernel engineered from the ground up for the Redmi 9 Power. This project transforms a standard consumer smartphone into a weaponized penetration testing platform with out-of-tree Wi-Fi packet injection and full hardware UART debugging capabilities.

---

## ⚡ Features
- **Packet Injection**: Native `mac80211` subsystem support.
- **Out-of-Tree Drivers**: Pre-compiled and systemlessly injected via Magisk:
  - **RTL8188EUS** (`8188eu.ko`) - For TP-Link TL-WN722N (V2/V3)
  - **RTL8812AU** (`8812au.ko` / `88XXau.ko`) - For TP-Link AC600
- **BadUSB / HID Attacks**: `CONFIG_HIDRAW` enabled for keyboard emulation.
- **Hardware Hacking**: Native UART/USB-Serial drivers baked directly into the kernel (`CP210X`, `FTDI_SIO`, `CH341`, `PL2303`).
- **Bloat-Free**: Stripped of unused generic adapters (Atheros/Ralink) for maximum efficiency while preserving Qualcomm's internal Audio and Wi-Fi.

---

## 🛠️ Required Assets
Before starting, ensure you have the following installed on your PC and Phone:
- [Android SDK Platform-Tools (ADB & Fastboot)](https://developer.android.com/tools/releases/platform-tools)
- **Custom Recovery**: [OrangeFox Recovery (Unofficial) for Chime](https://sourceforge.net/projects/joes-android-builds/files/recovery/OrangeFox-R12.0_14-Unofficial-chime.zip/download) (Required for flashing custom ROMs and Magisk).
- [Magisk App](https://github.com/topjohnwu/Magisk) installed on your rooted Redmi 9 Power.
- [Kali NetHunter Store App](https://store.nethunter.com/) installed on your phone.
- **Crucial Hardware**: An **OTG Y-Cable** or Powered USB Hub. *(See the Hardware Limitations section below).*

---

## 🚀 Installation Guide

### Step 0: Pre-requisites (ROM & Recovery)
1. Ensure your bootloader is unlocked.
2. Flash **OrangeFox Recovery** to your device.
3. Flash the recommended **LineageOS 20** custom ROM via OrangeFox.
4. Flash **Magisk** via OrangeFox to obtain root access, then reboot into the system.

### Step 1: Flash the NetHunter Kernel
Once you are booted into LineageOS 20 and have root access:
1. Reboot your phone into **Fastboot mode** (Power off, then hold Volume Down + Power).
2. Connect the phone to your PC via USB.
3. Open a terminal in your PC's `platform-tools` folder and run the following commands to flash the custom kernel:
```bash
fastboot flash boot nethunter-boot-v0.1.0.img
fastboot reboot
```

### Step 2: Inject the Wireless Drivers (Magisk Module)
The kernel is now installed, but Android's `/vendor` partition is read-only. We must use Magisk to inject the Wi-Fi drivers systemlessly.
1. Transfer the `chime-nethunter-modules-v0.1.0.zip` file to your phone's internal storage.
2. Open the **Magisk App** on your phone.
3. Tap on the **Modules** tab at the bottom right.
4. Tap **Install from storage** and select the `chime-nethunter-modules-v0.1.0.zip` file.
5. Once the installation finishes, tap the **Reboot** button at the bottom.

### Step 3: Install the Kali Linux Environment (Chroot)
To actually use the hacking tools (like `airodump-ng`), you need the Kali Linux environment.
1. Download and install the **NetHunter Store App**.
2. From the store, install the **NetHunter App** and the **NetHunter Terminal**.
3. Open the **NetHunter App** and grant it root permissions.
4. Navigate to the **Kali Chroot Manager** in the side menu.
5. Tap **Install Chroot** and select the "Minimal" or "Full" package (ensure you have at least 8GB of free storage).
6. Once the installation completes, start the Chroot. You now have a full, persistent Kali Linux shell!

---

## 📡 Using External Wi-Fi Adapters

### ⚠️ IMPORTANT: The Qualcomm PMIC Hardware Limitation
The Power Management IC (PMIC) on the Redmi 9 Power is hardcoded in the kernel to output a maximum of **1.5 Amps (1500mA)** via OTG (`qcom,otg-cl-ua = MICRO_1P5A`). High-gain Wi-Fi adapters like the AC600 pull a massive inrush current when initializing, which trips the PMIC's Over Current Protection (OCP) and instantly kills power to the USB port.
**Fix**: You *must* use an **OTG Y-Cable** to inject 5V power from an external battery bank. The phone handles the data; the battery bank handles the electricity.

### The RTL8812AU Monitor Mode Quirk
Do not use `airmon-ng start wlan1` to enable monitor mode with the AC600! The Realtek driver rejects the creation of `wlan1mon` virtual interfaces. You must set the physical interface into monitor mode manually.

Open your NetHunter Terminal, select Kali, and run:
```bash
# 1. Bring the interface down
ifconfig wlan1 down

# 2. Force monitor mode
iw dev wlan1 set type monitor

# 3. Bring the interface back up
ifconfig wlan1 up

# 4. Start sniffing!
airodump-ng wlan1
```

---

## 💻 Connecting via Wireless Debugging (ADB TCP/IP)
To easily debug the OTG port while leaving it free for your Wi-Fi adapters, use ADB over Wi-Fi.
1. Connect your phone to your PC via USB.
2. Run `adb tcpip 5555`.
3. Disconnect the USB cable.
4. Find your phone's IP address (e.g., `192.168.1.15`) and run:
   ```bash
   adb connect 192.168.1.15:5555
   ```
5. You can now plug your Wi-Fi adapter into the phone and read live kernel logs remotely by running `adb shell dmesg`.

---

## 🔗 Source Code & References
- **Recommended Custom ROM**: [LineageOS 20 (by joes-android-builds)](https://sourceforge.net/projects/joes-android-builds/files/LineageOS/20/)
- **Recommended Recovery**: [OrangeFox Recovery R12.0 Unofficial](https://sourceforge.net/projects/joes-android-builds/files/recovery/OrangeFox-R12.0_14-Unofficial-chime.zip/download)
- **Kernel Base Source**: [LineageOS SM6115 / Bengal Kernel (Linux 4.19)](https://github.com/LineageOS/android_kernel_xiaomi_sm6115)
- **RTL8188EUS Driver Source**: [aircrack-ng/rtl8188eus](https://github.com/aircrack-ng/rtl8188eus)
- **RTL8812AU Driver Source**: [aircrack-ng/rtl8812au](https://github.com/aircrack-ng/rtl8812au)
- **NetHunter Installer & Core**: [Offsec NetHunter Devices](https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-devices)
