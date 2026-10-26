#!/system/bin/sh
# ==============================================================================
# service_openwrt_autorun.sh
# Magisk / KernelSU boot service for the OpenWrt 5G router.
#
# Install:
#   adb push service_openwrt_autorun.sh /data/adb/service.d/
#   adb shell su -c "chmod 755 /data/adb/service.d/service_openwrt_autorun.sh"
#
# Scripts are expected in /data/adb/openwrt/; state/rootfs live in /data/openwrt/.
# ==============================================================================

sleep 20

# Optional headless power tuning (only when explicitly enabled).
if [ -f "/data/openwrt/enable_headless" ] && [ -f "/data/adb/openwrt/05_headless_power_control.sh" ]; then
    sh /data/adb/openwrt/05_headless_power_control.sh > /data/openwrt/power.log 2>&1
fi

# Wait for the 5G data interface. Prefer the clat IPv4 interface when the
# carrier is IPv6-only (464XLAT).
RETRY=0
while [ $RETRY -lt 30 ]; do
    FOUND=0
    for iface in v4-rmnet_data0 rmnet_data0 rmnet_data1 rmnet0; do
        if ip addr show "$iface" 2>/dev/null | grep -q "inet "; then
            FOUND=1
            break
        fi
    done
    [ $FOUND -eq 1 ] && break
    sleep 2
    RETRY=$((RETRY + 1))
done

# Start and keep the container alive. 04 is idempotent: it stops any old
# container, recreates the veth pair, and re-applies the host rules.
while true; do
    if ! pgrep -f "/data/openwrt/rootfs/sbin/procd" >/dev/null 2>&1; then
        sh /data/adb/openwrt/04_start_openwrt_and_network.sh > /data/openwrt/network.log 2>&1
    fi
    sleep 30
done
