#!/bin/bash
set -e

STAGING="/mnt/e/MI9power/chime-nethunter-work/magisk_v0.1.0"
OUT_DIR="/home/letchu/lime-phase1/out"
WORK_DIR="/mnt/e/MI9power/chime-nethunter-work"

echo "--- CLEANING STAGING DIR ---"
rm -rf "$STAGING"
mkdir -p "$STAGING/system/vendor/lib/modules"

echo "--- CREATING module.prop ---"
cat <<EOF > "$STAGING/module.prop"
id=chime-nethunter-modules
name=Chime NetHunter Custom Kernel Modules
version=v0.1.0
versionCode=10
author=@l3tchupkt
description=Restores internal Wi-Fi/Audio, and adds NetHunter wireless injection modules (rtl8188eus, rtl8812au). Atheros/Ralink stripped.
EOF

echo "--- COPYING INTERNAL MODULES ---"
# WLAN
cp /mnt/e/MI9power/chime-nethunter-work/qca_cld3_wlan.ko "$STAGING/system/vendor/lib/modules/" || true
# Audio
find "$OUT_DIR/techpack/audio" -name '*.ko' -exec cp {} "$STAGING/system/vendor/lib/modules/" \; || true

echo "--- COPYING PHASE 3 REALTEK MODULES ---"
find "$WORK_DIR/rtl8188eus" -name '8188eu.ko' -exec cp {} "$STAGING/system/vendor/lib/modules/" \; || true
find "$WORK_DIR/rtl8812au" -name '8812au.ko' -exec cp {} "$STAGING/system/vendor/lib/modules/" \; || true
find "$WORK_DIR/rtl8812au" -name '88XXau.ko' -exec cp {} "$STAGING/system/vendor/lib/modules/" \; || true

echo "--- ZIPPING MODULE ---"
cd "$STAGING"
zip -r ../chime-nethunter-modules-v0.1.0.zip .

echo "Done! Output is chime-nethunter-modules-v0.1.0.zip"
