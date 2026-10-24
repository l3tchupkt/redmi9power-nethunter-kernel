# Xiaomi Chime/Lime Audio Subsystem Repair & Kernel Module Architecture

**Device:** Xiaomi Redmi 9 Power / Redmi Note 9 4G / Poco M3 (`lime` / `chime` / `citrus`)  
**SoC:** Qualcomm Snapdragon 662 (Bengal / SM6115)  
**OS Base:** LineageOS 20 (Android 13, API 33)  
**Kernel:** `4.19.225-lilium-perf` (SMP PREEMPT aarch64)  
**Status:** **VERIFIED WORKING** (Card 0 `bengal-idp-snd-card` active, 31 PCM streams, speaker & headset functional)

---

## 1. Problem Statement & Initial Failure Analysis

When booting a custom NetHunter kernel on LineageOS 20 (`chime/lime`), the system experienced complete audio loss:
- `/proc/asound/cards` returned: `--- no soundcards ---`.
- `/proc/asound/pcm` was completely empty.
- AudioFlinger failed to initialize audio HAL (`audio.primary.bengal`).
- Applications requiring audio input/output (media players, SDR++, voice calls) either crashed or remained silent.

### Root Cause: Why Magisk Overlay Failed
Initially, an attempt was made to inject rebuilt audio kernel modules systemlessly via a Magisk module (`/system/vendor/lib/modules`). This failed due to an Android init boot sequence timing constraint:
1. **Early Kernel Module Loading:** On Qualcomm Bengal platforms, the Android init system loads audio modules during `on early-init` directly from physical `/vendor/lib/modules/` (measured in kernel `dmesg` logs on our LineageOS 20 test device at **T ≈ 2.11 seconds** after boot).
2. **Peripheral Image Loader (PIL) Lockup:** When the sound machine driver (`audio_machine_bengal.ko`) fails to find the codec drivers at `early-init`, the Hexagon DSP (ADSP) Peripheral Image Loader (PIL) encounters a binding timeout.
3. **Magisk Late Mount:** Magisk systemless overlays are mounted during `post-fs-data` (observed in logcat/dmesg at **T > 8.0 seconds** after boot). By the time Magisk overlayed the modules, the Hexagon DSP subsystem had already timed out and refused to re-bind.
*(Note: These timestamps reflect measured observations from dmesg logs on this specific device and LineageOS 20 build; they illustrate the architectural necessity of recovery-level vendor installation rather than universal timing constants across all Android devices.)*
4. **Conclusion:** Audio kernel modules on this platform **must reside directly in the physical vendor partition** (`/vendor/lib/modules/`).

---

## 2. Kernel ABI & Hardware Verification

### A. Module ABI & Symbol Audit
All 28 rebuilt audio modules were compiled against the target kernel build environment and audited against `/out/Module.symvers`:
- **Vermagic:** `4.19.225-lilium-perf SMP preempt mod_unload modversions aarch64`
- **Symbol CRC Audit:** **1,782 / 1,782** imported symbol CRCs matched bit-for-bit with **0 mismatches** and **0 unresolved dependencies**.

### B. Hardware Device Tree Audit: WSA881x vs AW87359
A critical point in the repair was determining whether the reference WSA881x speaker amplifier belonged on this device:
- Inspection of the live device tree node `/soc/i2c@4a84000/wsa881x-i2c-codec@e` confirmed `status = "disable"`.
- Inspection of `/soc/i2c@4a84000/aw87359@58` confirmed `status = "okay"` (`awinic,aw87359_pa`).
- The stock vendor partition ships `audio_aw87359.ko` and `audio_aw882xx.ko` for dual Awinic smart speaker amplifiers. It **does not ship** `audio_wsa881x_analog.ko`, and stock `modules.dep` contains no reference to WSA881x.
- **Decision:** `audio_wsa881x_analog.ko` is unpopulated reference Qualcomm hardware and must be **excluded**. Factory `modules.dep` must remain pristine.

---

## 3. Atomic Recovery Package Architecture (v2.8)

To safely install the rebuilt audio modules without bootloops or brick risk, an atomic, fail-safe recovery installer and standalone rollback package were developed:

- **Installer Package:** `chime-audio-test-v2.zip` (SHA-256: `b8ce0e2c992d48ba9d9181075d9caade5a8f8bcc79a276118c6604266d4a881b`)
- **Rollback Package:** `chime-audio-rollback-v2.zip` (SHA-256: `00805e9b9b9f0368ea87f6bf84d03f86e00107eccb5e7cbe4e2878793e25d03e`)
- **Raw Vendor Backup:** `vendor_backup.img` (1,012,473,856 bytes, SHA-256: `6b4f31af379b479f04c04a29c1f92be44163c95c6e67b9bf9c4a436045c9843c`)

### 8-Stage Fail-Safe Execution Flow
1. **Environment & Codename Check:** Validates `ro.product.device` is strictly `lime` or `chime`.
2. **Block Device Validation:** Asserts `/dev/block/mapper/vendor` exists.
3. **Preflight Package Check:** Cryptographically verifies all 28 source modules against `manifest.sha256` before touching `/vendor`.
4. **Safe Read-Only Mount:** Mounts `/vendor` `ro` to inspect stock modules.
5. **Persistent Stock Backup:** Stages, verifies, and promotes a bit-exact backup of the 26 stock modules and `modules.dep` to `/data/local/tmp/stock_audio_modules_backup/`. If an existing backup is damaged, the installer halts immediately rather than overwriting it with modified files.
6. **Remount Read-Write & Arm Trap:** Remounts `/vendor` `rw` and arms an emergency rollback signal trap (`INT`, `TERM`).
7. **Module Copy & Metadata Enforcement:** Installs 28 modules, setting and reading back `0644 0:0 u:object_r:vendor_file:s0` on every file. Asserts `modules.dep` remains pristine.
8. **Post-Install Checksums & Clean Unmount:** Validates all destination SHA-256 hashes on disk, flushes buffers (`sync`), and unmounts `/vendor` cleanly.

---

## 4. Verification Evidence & Post-Boot Test Results

### ALSA Sound Cards (`/proc/asound/cards`)
```text
 0 [bengalidpsndcar]: bengal-idp-snd- - bengal-idp-snd-card
                      bengal-idp-snd-card
```

### PCM Streams (`/proc/asound/pcm`)
31 distinct audio endpoints registered:
```text
00-00: MultiMedia1 (*) :  : playback 1 : capture 1
00-01: MultiMedia2 (*) :  : playback 1 : capture 1
00-02: VoiceMMode1 (*) :  : playback 1 : capture 1
00-03: VoIP (*) :  : playback 1 : capture 1
00-04: MultiMedia3 (*) :  : playback 1
00-05: AFE-PROXY RX msm-stub-rx-5 :  : playback 1
00-06: AFE-PROXY TX msm-stub-tx-6 :  : capture 1
00-08: AUXPCM Hostless (*) :  : playback 1 : capture 1
...
00-38: TX CDC DMA5 Capture tx_macro_tx3-38 :  : capture 1
```

### Kernel `dmesg` Registration Log
```text
[   11.339749] input: bengal-idp-snd-card Headset Jack as /devices/platform/soc/.../sound/card0/input6
[   11.340426] input: bengal-idp-snd-card Button Jack as /devices/platform/soc/.../sound/card0/input7
[   11.341599] bengal-asoc-snd soc:qcom,msm-audio-apr:qcom,q6core-audio:sound: msm_asoc_machine_probe: Sound card bengal-idp-snd-card registered
[   26.638508] aw87359_audio_dspk enter
[   26.645017] aw87519_audio_kspk enter
```

### Hardware Audio Output Test
Audio HAL and AudioFlinger logs confirm hardware routing and playback:
```text
msm8974_platform: platform_check_and_set_codec_backend_cfg: afe: bitwidth 24, samplerate 48000 channels 2, device (speaker)
audio_hw_primary: enabling usecase (low-latency-playback) on (speaker)
audio_hw_primary: enable_snd_device: snd_device(2: speaker)
audio_hw_primary: enable_audio_route: apply mixer and update path: low-latency-playback
audio_hw_primary: out_standby: enter: stream usecase(1: low-latency-playback)
audio_hw_primary: disable_snd_device: snd_device(2: speaker)
```

---

## 5. Rollback & Emergency Recovery Hierarchy

If audio repair ever needs to be reverted or re-tested:

1. **Tier 1 (Targeted Package Rollback):**  
   Flash `chime-audio-rollback-v2.zip` via OrangeFox Recovery.  
   - Restores the 26 stock modules from `/data/local/tmp/stock_audio_modules_backup/`.
   - Restores factory `modules.dep`.
   - Deletes newly added Awinic modules.
   - Verifies read-back permissions (`0644 0:0 u:object_r:vendor_file:s0`).
   - Unmounts `/vendor` cleanly.

2. **Tier 2 (Raw Partition Image Restore - Last Resort Only):**  
   Only if partition structures or filesystems are corrupt:
   ```bash
   adb shell "dd if=/data/local/tmp/vendor_backup.img of=/dev/block/mapper/vendor bs=4096"
   ```
   *Warning:* Verify target block device and matching file size (`1,012,473,856` bytes) before running raw image restore.