#!/usr/bin/env bash
# ==============================================================================
# NetHunter External Wireless Module Magisk Packager (lime/chime/citrus)
# Targets: RTL8812AU (88XXau.ko / 8812au.ko) & RTL8188EUS (8188eu.ko)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

MODULE_ID="chime-nethunter-wireless"
MODULE_NAME="Chime NetHunter Wireless Injection Modules"
MODULE_VERSION="${MODULE_VERSION:-v0.1.0}"
VERSION_CODE="${VERSION_CODE:-10}"
AUTHOR="@l3tchupkt"

# Configurable paths with defaults
STAGING_BASE="${STAGING_DIR:-$REPO_ROOT/out/staging}"
STAGING_DIR="$STAGING_BASE/magisk_${MODULE_VERSION}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/../chime-nethunter-work}"
ZIP_NAME="${MODULE_ID}-${MODULE_VERSION}.zip"
INCLUDE_INTERNAL_WLAN="${INCLUDE_INTERNAL_WLAN:-0}"

# --- Path Safety Validation ---
validate_safe_path() {
    local target="$1"
    local desc="$2"

    if [ -z "$target" ]; then
        echo "ERROR: $desc path is empty." >&2
        return 1
    fi

    local normalized
    normalized="$(echo "$target" | sed 's|/\{1,\}|/|g; s|/$||')"

    case "$normalized" in
        ""|"/"|"/root"|"/home"|"/bin"|"/usr"|"/etc"|"/var"|"/data"|"/tmp")
            echo "FATAL: Dangerous $desc path rejected: '$target'" >&2
            return 1
            ;;
    esac

    # Ensure staging path is inside out/ or a designated build path
    if [ "$desc" = "STAGING_DIR" ]; then
        case "$normalized" in
            *"$REPO_ROOT/out"*|*"$REPO_ROOT/build"*|*"/tmp/test_"*)
                ;;
            "$REPO_ROOT"|"$REPO_ROOT/"*)
                if [ "$normalized" = "$REPO_ROOT" ]; then
                    echo "FATAL: STAGING_DIR cannot be repository root." >&2
                    return 1
                fi
                ;;
            *)
                echo "WARNING: STAGING_DIR is outside standard out/ tree: '$target'" >&2
                ;;
        esac
    fi
    return 0
}

# --- Module Validation Helper ---
validate_kernel_module() {
    local mod="$1"
    local expected_name="$2"

    if [ ! -f "$mod" ]; then
        return 1
    fi

    # Non-zero size check
    if [ ! -s "$mod" ]; then
        echo "WARNING: Module $mod is 0 bytes. Skipping." >&2
        return 1
    fi

    # Check ELF Magic (7f 45 4c 46) and 64-bit AArch64
    if command -v readelf >/dev/null 2>&1; then
        local machine
        machine=$(readelf -h "$mod" 2>/dev/null | grep -i "Machine:" || true)
        if [ -n "$machine" ] && ! echo "$machine" | grep -qE "AArch64|ARM aarch64"; then
            echo "WARNING: $mod architecture mismatch ($machine). Expected AArch64." >&2
            return 1
        fi
    fi

    # Check vermagic string if strings utility is available
    if command -v strings >/dev/null 2>&1; then
        local vmagic
        vmagic=$(strings "$mod" 2>/dev/null | grep -E '^vermagic=' | head -n1 || true)
        if [ -n "$vmagic" ] && ! echo "$vmagic" | grep -q "4.19"; then
            echo "WARNING: $mod vermagic mismatch ($vmagic). Expected 4.19.x." >&2
            return 1
        fi
    fi

    return 0
}

echo "=================================================="
echo " Packaging NetHunter Magisk Module"
echo " ID      : $MODULE_ID"
echo " Version : $MODULE_VERSION ($VERSION_CODE)"
echo " Target  : $OUT_DIR/$ZIP_NAME"
echo "=================================================="

validate_safe_path "$STAGING_DIR" "STAGING_DIR"
validate_safe_path "$OUT_DIR" "OUT_DIR"

# Safe staging recreation
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/system/vendor/lib/modules"

# Generate module.prop
cat <<EOF > "$STAGING_DIR/module.prop"
id=${MODULE_ID}
name=${MODULE_NAME}
version=${MODULE_VERSION}
versionCode=${VERSION_CODE}
author=${AUTHOR}
description=Injects out-of-tree Wi-Fi packet injection modules (RTL8812AU, RTL8188EUS) for Kali NetHunter on Xiaomi Redmi 9 Power / Poco M3.
EOF

# Generate hardened service.sh
cat <<'EOF' > "$STAGING_DIR/service.sh"
#!/system/bin/sh
# ==============================================================================
# NetHunter Wireless Drivers Service-Stage Module Loader
# Executed by Magisk late_start service mode
# ==============================================================================
MOD_DIR="/data/adb/modules/chime-nethunter-wireless/system/vendor/lib/modules"
LOG_FILE="/data/local/tmp/nethunter-modules.log"

log_msg() {
    local msg="[NetHunter-Modules] $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >> "$LOG_FILE" 2>/dev/null || true
    echo "$msg" > /dev/kmsg 2>/dev/null || true
}

log_msg "Starting NetHunter wireless module loader service..."

if [ ! -d "$MOD_DIR" ]; then
    log_msg "ERROR: Module directory not found: $MOD_DIR"
    exit 0
fi

# Load RTL8188EUS (TP-Link TL-WN722N v2/v3)
if [ -f "$MOD_DIR/8188eu.ko" ]; then
    if ! grep -q "^8188eu " /proc/modules 2>/dev/null; then
        if insmod "$MOD_DIR/8188eu.ko" 2>/dev/null; then
            log_msg "Successfully loaded 8188eu.ko"
        else
            log_msg "Notice: 8188eu.ko insmod returned non-zero (may load on adapter attach)"
        fi
    else
        log_msg "8188eu is already loaded."
    fi
fi

# Load RTL8812AU / RTL8821AU (AC600 / Alfa AWUS036ACH)
# Prioritize 88XXau.ko over 8812au.ko
RTL88_MOD=""
if [ -f "$MOD_DIR/88XXau.ko" ]; then
    RTL88_MOD="$MOD_DIR/88XXau.ko"
elif [ -f "$MOD_DIR/8812au.ko" ]; then
    RTL88_MOD="$MOD_DIR/8812au.ko"
fi

if [ -n "$RTL88_MOD" ]; then
    mod_base=$(basename "$RTL88_MOD" .ko)
    if ! grep -q "^${mod_base} " /proc/modules 2>/dev/null; then
        if insmod "$RTL88_MOD" 2>/dev/null; then
            log_msg "Successfully loaded $(basename "$RTL88_MOD")"
        else
            log_msg "Notice: $(basename "$RTL88_MOD") insmod returned non-zero (may load on adapter attach)"
        fi
    else
        log_msg "$mod_base is already loaded."
    fi
fi

# Optional Internal WLAN module (qcacld-3.0)
if [ -f "$MOD_DIR/qca_cld3_wlan.ko" ]; then
    if ! grep -q "^wlan " /proc/modules 2>/dev/null; then
        if insmod "$MOD_DIR/qca_cld3_wlan.ko" 2>/dev/null; then
            log_msg "Successfully loaded qca_cld3_wlan.ko"
        fi
    fi
fi

log_msg "NetHunter wireless module loader service completed."
exit 0
EOF
chmod 755 "$STAGING_DIR/service.sh"

MODULES_STAGED=0

# Stage RTL8188EUS
RTL8188_PATH=$(find "$OUT_DIR/modules" "$WORK_DIR" "$REPO_ROOT" -maxdepth 4 -name "8188eu.ko" -type f 2>/dev/null | head -n1 || true)
if [ -n "$RTL8188_PATH" ] && validate_kernel_module "$RTL8188_PATH" "8188eu.ko"; then
    cp "$RTL8188_PATH" "$STAGING_DIR/system/vendor/lib/modules/8188eu.ko"
    echo "  [+] Staged: 8188eu.ko ($(stat -c%s "$RTL8188_PATH" 2>/dev/null || wc -c < "$RTL8188_PATH") bytes)"
    MODULES_STAGED=$((MODULES_STAGED + 1))
else
    echo "  [-] RTL8188EUS (8188eu.ko) not found."
fi

# Stage RTL8812AU (Prefer 88XXau.ko over 8812au.ko, avoid duplicate packaging)
RTL88_PATH=$(find "$OUT_DIR/modules" "$WORK_DIR" "$REPO_ROOT" -maxdepth 4 -name "88XXau.ko" -type f 2>/dev/null | head -n1 || true)
if [ -z "$RTL88_PATH" ]; then
    RTL88_PATH=$(find "$OUT_DIR/modules" "$WORK_DIR" "$REPO_ROOT" -maxdepth 4 -name "8812au.ko" -type f 2>/dev/null | head -n1 || true)
fi

if [ -n "$RTL88_PATH" ] && validate_kernel_module "$RTL88_PATH" "$(basename "$RTL88_PATH")"; then
    cp "$RTL88_PATH" "$STAGING_DIR/system/vendor/lib/modules/$(basename "$RTL88_PATH")"
    echo "  [+] Staged: $(basename "$RTL88_PATH") ($(stat -c%s "$RTL88_PATH" 2>/dev/null || wc -c < "$RTL88_PATH") bytes)"
    MODULES_STAGED=$((MODULES_STAGED + 1))
else
    echo "  [-] RTL8812AU (88XXau.ko / 8812au.ko) not found."
fi

# Optional Internal WLAN staging
if [ "$INCLUDE_INTERNAL_WLAN" -eq 1 ]; then
    WLAN_PATH=$(find "$OUT_DIR/modules" "$WORK_DIR" "$REPO_ROOT" -maxdepth 4 -name "qca_cld3_wlan.ko" -type f 2>/dev/null | head -n1 || true)
    if [ -n "$WLAN_PATH" ] && validate_kernel_module "$WLAN_PATH" "qca_cld3_wlan.ko"; then
        cp "$WLAN_PATH" "$STAGING_DIR/system/vendor/lib/modules/qca_cld3_wlan.ko"
        echo "  [+] Staged (Optional): qca_cld3_wlan.ko"
        MODULES_STAGED=$((MODULES_STAGED + 1))
    fi
fi

# Fail if no valid modules were staged
if [ "$MODULES_STAGED" -eq 0 ]; then
    echo "**************************************************" >&2
    echo "ERROR: No valid kernel modules were found to package!" >&2
    echo "Refusing to build an empty Magisk module." >&2
    echo "Please compile or place wireless modules before running." >&2
    echo "**************************************************" >&2
    rm -rf "$STAGING_DIR"
    exit 1
fi

# Package ZIP
mkdir -p "$OUT_DIR"
PACKAGE_PATH="$OUT_DIR/$ZIP_NAME"
rm -f "$PACKAGE_PATH"
(cd "$STAGING_DIR" && zip -r -q "$PACKAGE_PATH" .)

# Cleanup staging
rm -rf "$STAGING_DIR"

echo "=================================================="
echo " Magisk Module Created Successfully:"
echo " File: $PACKAGE_PATH ($(stat -c%s "$PACKAGE_PATH" 2>/dev/null || wc -c < "$PACKAGE_PATH") bytes)"
if command -v sha256sum >/dev/null 2>&1; then
    echo " SHA-256: $(sha256sum "$PACKAGE_PATH" | awk '{print $1}')"
fi
echo " Modules included: $MODULES_STAGED"
echo "=================================================="