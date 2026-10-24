#!/usr/bin/env bash
# ==============================================================================
# NetHunter Wireless Driver Magisk Packaging Script (lime/chime)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

MODULE_VERSION="${MODULE_VERSION:-v0.1.0}"
VERSION_CODE="${VERSION_CODE:-10}"
STAGING_DIR="${STAGING_DIR:-$REPO_ROOT/staging/magisk_${MODULE_VERSION}}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/../chime-nethunter-work}"
ZIP_NAME="chime-nethunter-modules-${MODULE_VERSION}.zip"

echo "=================================================="
echo " Packaging NetHunter Magisk Module: $ZIP_NAME"
echo "=================================================="

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/system/vendor/lib/modules"

cat <<EOF > "$STAGING_DIR/module.prop"
id=chime-nethunter-modules
name=Chime NetHunter Custom Kernel Modules
version=${MODULE_VERSION}
versionCode=${VERSION_CODE}
author=@l3tchupkt
description=Restores internal Wi-Fi/Audio, and adds NetHunter wireless injection modules (rtl8188eus, rtl8812au). Atheros/Ralink stripped.
EOF

cat <<'EOF' > "$STAGING_DIR/service.sh"
#!/system/bin/sh
# Optional post-boot module loader for out-of-tree drivers
MOD_DIR="/data/adb/modules/chime-nethunter-modules/system/vendor/lib/modules"
if [ -d "$MOD_DIR" ]; then
    insmod "$MOD_DIR/8188eu.ko" 2>/dev/null || true
    insmod "$MOD_DIR/88XXau.ko" 2>/dev/null || insmod "$MOD_DIR/8812au.ko" 2>/dev/null || true
fi
EOF
chmod 755 "$STAGING_DIR/service.sh"

COPIED=0

# Copy WLAN module
if [ -f "$OUT_DIR/modules/qca_cld3_wlan.ko" ]; then
    cp "$OUT_DIR/modules/qca_cld3_wlan.ko" "$STAGING_DIR/system/vendor/lib/modules/"
    COPIED=$((COPIED + 1))
elif [ -f "$WORK_DIR/qca_cld3_wlan.ko" ]; then
    cp "$WORK_DIR/qca_cld3_wlan.ko" "$STAGING_DIR/system/vendor/lib/modules/"
    COPIED=$((COPIED + 1))
fi

# Copy Realtek modules
for rmod in 8188eu.ko 88XXau.ko 8812au.ko; do
    found=$(find "$OUT_DIR/modules" "$WORK_DIR" -name "$rmod" -type f 2>/dev/null | head -n1 || true)
    if [ -n "$found" ] && [ -f "$found" ]; then
        cp "$found" "$STAGING_DIR/system/vendor/lib/modules/"
        COPIED=$((COPIED + 1))
        echo "Staged: $rmod (from $found)"
    fi
done

if [ "$COPIED" -eq 0 ]; then
    echo "WARNING: No modules were found to stage into the Magisk package."
fi

mkdir -p "$OUT_DIR"
cd "$STAGING_DIR"
zip -r "$OUT_DIR/$ZIP_NAME" .

echo "=================================================="
echo " Magisk Module Created: $OUT_DIR/$ZIP_NAME"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$OUT_DIR/$ZIP_NAME"
fi
echo "=================================================="