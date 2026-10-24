# RTL-SDR Integration & Software Defined Radio Guide

**Device:** Xiaomi Redmi 9 Power / Poco M3 (`chime/lime`)  
**Supported Applications:** SDR++, RF Analyzer, Kali NetHunter (`rtl_test`, `rtl_tcp`)  
**Status:** **VERIFIED WORKING** (RTL-SDR dongle tested, RF Analyzer operational, SDR++ functional with audio sink)

---

## 1. Overview of RTL-SDR Support on Android

Using an RTL-SDR USB dongle on Android introduces distinct architectural layers:

```
+-------------------------------------------------------------+
|                     Android User Space                      |
|                                                             |
|   +-----------------------+     +-----------------------+   |
|   |         SDR++         |     |      RF Analyzer      |   |
|   |    (Direct USB or     |     |   (Requires external  |   |
|   |       RTL-TCP)        |     |      driver app)      |   |
|   +-----------+-----------+     +-----------+-----------+   |
|               |                             |               |
|               | Android UsbManager          | Intent/Socket |
|               | (Cold-start permission)     | (iqsrc://)    |
|               v                             v               |
|      [ Android USB Host ]       [ marto.rtl_tcp_andro ]     |
+---------------+-----------------------------+---------------+
|               |                             |               |
|               +--------------+--------------+               |
|                              |                              |
|                              v                              |
|               [ /dev/bus/usb/00X/00Y ]                      |
|                 (0660 root:usb)                             |
|                              ^                              |
|                              | Direct Root Access           |
|                 +------------+------------+                 |
|                 |   Kali NetHunter Chroot |                 |
|                 |   (rtl_test / rtl_tcp)  |                 |
|                 +-------------------------+                 |
+-------------------------------------------------------------+
|                     Linux Kernel 4.19                       |
|           DWC3 USB Host Controller + OTG Interface          |
+-------------------------------------------------------------+
|             RTL2832U / R820T2 USB Hardware Dongle           |
+-------------------------------------------------------------+
```

---

## 2. Testing in Kali NetHunter (`rtl_test`)

Because Kali NetHunter chroot runs with root privileges (`uid=0, gid=0`), it can open character device nodes under `/dev/bus/usb/` directly without needing Android USB permissions.

### Testing USB Dongle Health:
1. Connect the RTL-SDR to the phone via a USB-C OTG adapter.
2. Open NetHunter Terminal and launch a Kali shell (`bootkali` or NetHunter terminal app).
3. Run the benchmark tool:
   ```bash
   rtl_test -t
   ```
4. **Expected Output:**
   ```text
   Found 1 device(s):
     0:  Realtek, RTL2838UHIDIR, SN: 00000001
   Using device 0: Generic RTL2832U OEM
   Found Rafael Micro R820T tuner
   Supported gain values (29): 0.0 0.9 1.4 ... 49.6 dB
   Sampling at 2048000 S/s.
   No E4000 tuner found, aborting.
   ```
   If this outputs clean gain values and detects the tuner without I/O errors, the physical USB connection, OTG line, and tuner chip are 100% operational.

---

## 3. SDR++ Direct USB Detection & Cold-Start Behavior

SDR++ on Android bundles native drivers:
- `librtlsdr.so`
- `libusb1.0.so`
- `rtl_sdr_source.so`
- `audio_sink.so`

### The Cold-Start Requirement (Crucial)
SDR++ (`org.sdrpp.sdrpp`) has an architectural quirk:
1. `MainActivity.onCreate()` enumerates attached USB devices using `usbManager.getDeviceList()` and calls `usbManager.requestPermission()` **only once during activity creation**.
2. SDR++ **does not** contain a broadcast receiver for `android.hardware.usb.action.USB_DEVICE_ATTACHED`.
3. If you open SDR++ first and then plug in the RTL-SDR via OTG, SDR++ will **not** detect it, and the device dropdown under Source -> RTL-SDR will remain empty ("No device selected").

### Correct Connection Sequence for Direct USB:
1. **Force-stop SDR++** if it is running in the background:
   ```bash
   adb shell am force-stop org.sdrpp.sdrpp
   ```
   *(Or swipe it away from Recent Apps).*
2. **Plug the RTL-SDR into the phone via OTG first.**
3. **Launch SDR++ from the launcher.**
4. A system dialog will pop up:  
   *"Allow SDR++ to access RTL2838UHIDIR?"*
5. Check **"Always allow"** and tap **OK**.
6. In SDR++, set **Source** to **RTL-SDR**, tap **Refresh**, and select the device.
7. Tap the **Play** button to begin streaming I/Q samples.

---

## 4. Alternative: The Rock-Solid NetHunter RTL-TCP Daemon

If you prefer zero USB permission prompts, you can run a persistent `rtl_tcp` server inside NetHunter. This provides a universal TCP stream that any SDR software on the phone can connect to over `127.0.0.1:1234`.

### 1. Launch the Server in NetHunter
Inside the NetHunter terminal:
```bash
rtl_tcp -a 127.0.0.1 -p 1234
```
*(For RTL-SDR v4 or v3 dongles with bias-T for an active antenna, add `-T` to enable the bias-tee).*

### 2. Connect from SDR++
1. In SDR++, set **Source** to **RTL-TCP**.
2. Set Address: `127.0.0.1` and Port: `1234`.
3. Tap **Connect** and **Play**.

---

## 5. RF Analyzer Configuration

RF Analyzer (`com.mantz_it.rfanalyzer`) does **not** include an internal RTL-SDR driver. Instead, it relies on Martin Marinov's **RTL2832U driver app** (`marto.rtl_tcp_andro`).

### Setup Steps:
1. Ensure `marto.rtl_tcp_andro` is installed (available on Google Play / F-Droid).
2. Connect your RTL-SDR via OTG.
3. Open **RF Analyzer**.
4. In the top-right menu, select **Source** -> **RTL-SDR (USB)**.
5. Android will prompt to open the RTL2832U driver; tap **OK**.
6. The spectrum waterfall will begin rendering immediately.

*(Note: Never launch `marto.rtl_tcp_andro` manually from the app drawer without arguments; it is designed to be invoked by client apps like RF Analyzer).*

---

## 6. Audio Demodulation & Speaker Output

With the audio kernel repair in place (`bengal-idp-snd-card` active):
1. In SDR++, open the **Sinks** section in the left panel.
2. Select **Audio Sink** (device: default / speaker).
3. Under the **Radio** module, select your desired demodulation mode (WFM for broadcast radio, NFM for VHF/UHF, AM for aviation).
4. Audio output will route cleanly through the onboard stereo speakers or the 3.5mm headset jack without audio buffer underruns.