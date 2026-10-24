# Hardware Hacking, Wireless Injection & USB Gadget Reference

**Device:** Xiaomi Redmi 9 Power / Poco M3 (`chime/lime`)  
**Kernel:** `4.19.225-lilium-perf` (NetHunter Edition)  
**Status:** **VERIFIED WORKING** (UART serial, BadUSB HID, Wi-Fi injection, OTG verified)

---

## 1. External Wireless Penetration Testing

The NetHunter kernel features native out-of-tree drivers systemlessly loaded for high-power external Wi-Fi adapters:
- **RTL8188EUS** (`8188eu.ko`) — TP-Link TL-WN722N (v2/v3).
- **RTL8812AU** (`88XXau.ko` / `8812au.ko`) — Dual-Band AC600 / Alfa AWUS036ACH.

### ⚠️ Critical Hardware Warning: Qualcomm PMIC 1.5A Inrush Limit
The Power Management IC (PMIC) on the Redmi 9 Power enforces a strict hardware limit of **1.5 Amps (1500mA)** over OTG (`qcom,otg-cl-ua = MICRO_1P5A`).
- High-gain Wi-Fi cards (such as the Alfa AC600 or dual-band adapters) pull a massive inrush surge current when their radio chips power up.
- This trips the PMIC's Over Current Protection (OCP), causing the phone to immediately shut off power to the USB port.
- **Solution:** Always connect high-power Wi-Fi cards through an **OTG Y-Cable** or a powered USB hub. The battery pack provides 5V electrical power while the phone's Type-C port handles USB data lines.

### The RTL8812AU Monitor Mode Quirk
The Realtek driver for RTL8812AU rejects virtual monitor interfaces created by `airmon-ng start wlan1` (which produces error `-95 Operation not supported`).  
You **must** switch the physical interface into monitor mode directly using `iw`:

```bash
# 1. Bring the interface down
ifconfig wlan1 down

# 2. Put physical interface into monitor mode
iw dev wlan1 set type monitor

# 3. Bring the interface back up
ifconfig wlan1 up

# 4. Verify monitor mode
iw dev wlan1 info

# 5. Begin sniffing
airodump-ng wlan1
```

### Packet Injection Test
Test packet injection against an authorized AP:
```bash
aireplay-ng -9 wlan1
```
Expected output: `Injection is working!`.

---

## 2. Hardware UART / USB-Serial Hacking

Native USB-to-serial drivers are compiled directly into the kernel core (built-in, not modules):
- `CONFIG_USB_SERIAL=y`
- `CONFIG_USB_SERIAL_CP210X=y` (Silicon Labs CP2102/CP2104)
- `CONFIG_USB_SERIAL_FTDI_SIO=y` (FTDI FT232R)
- `CONFIG_USB_SERIAL_CH341=y` (Winchiphead CH340G / CH341A)
- `CONFIG_USB_SERIAL_PL2303=y` (Prolific PL2303)

### Usage:
When plugging in a USB-to-UART adapter via OTG:
1. Verify device registration:
   ```bash
   dmesg | grep -i ttyUSB
   ```
2. The serial interface appears as `/dev/ttyUSB0`.
3. Open a serial console in NetHunter using `minicom`, `screen`, or `picocom`:
   ```bash
   picocom -b 115200 /dev/ttyUSB0
   ```

---

## 3. BadUSB & HID Gadget Emulation

The kernel enables raw HID support (`CONFIG_HIDRAW=y`) and USB ConfigFS gadget endpoints:
- `CONFIG_USB_CONFIGFS_F_HID=y`
- `CONFIG_USB_CONFIGFS_RNDIS=y`
- `CONFIG_USB_CONFIGFS_ACM=y`

### Emulating Keystrokes:
The NetHunter app DuckHunter interface sends keystroke payloads to target machines via the USB gadget endpoint:
```bash
echo -ne "\0\0\x04\0\0\0\0\0" > /dev/hidg0 # Press 'a'
echo -ne "\0\0\0\0\0\0\0\0" > /dev/hidg0       # Release
```

---

## 4. Wireless Debugging (ADB over Wi-Fi)

To keep the phone's physical USB port free for OTG adapters (Wi-Fi cards, RTL-SDR, UART dongles), enable ADB over TCP/IP:

1. Connect the phone to your PC via USB cable.
2. In your PC terminal:
   ```bash
   adb tcpip 5555
   ```
3. Disconnect the USB cable.
4. Obtain your phone's Wi-Fi IP address (Settings -> Wi-Fi or `adb shell ip -4 addr show wlan0`).
5. Connect wirelessly:
   ```bash
   adb connect <PHONE_IP>:5555
   ```
6. You can now monitor live kernel logs (`adb shell dmesg -w`) and logcat over Wi-Fi while external hardware is connected to the USB-C port.