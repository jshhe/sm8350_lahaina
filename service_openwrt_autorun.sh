#!/system/bin/sh
# ==============================================================================
# service_openwrt_autorun.sh
# Magisk late_start service: bring up the OpenWrt 5G router container on boot
# and keep it alive.
#
# Install:
#   adb push service_openwrt_autorun.sh /data/adb/service.d/
#   adb shell su -c "chmod 755 /data/adb/service.d/service_openwrt_autorun.sh"
#
# Disable without removing:
#   touch /data/openwrt/disable_autorun
# ==============================================================================
export PATH=/data/adb/magisk:/system/bin:/system/xbin:$PATH

BB=/data/adb/magisk/busybox
LOG=/data/openwrt/logs/autorun.log
PIDFILE=/data/openwrt/run/container.pid
mkdir -p /data/openwrt/logs /data/openwrt/run

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

container_running() {
    [ -f "$PIDFILE" ] || return 1
    pid=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$pid" ] && [ -d "/proc/$pid" ] || return 1
    # PID reuse guard: the init's root must be the OpenWrt rootfs.
    root=$($BB readlink "/proc/$pid/root" 2>/dev/null)
    case "$root" in
        *openwrt/rootfs*) return 0 ;;
    esac
    return 1
}

# Android's netd resets ip_forward and the policy rules when the network
# changes (hotspot off, USB NIC plug, 5G reconnect).  Re-assert them.
ensure_wan() {
    [ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" = "1" ] || echo 1 > /proc/sys/net/ipv4/ip_forward
    [ "$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null)" = "1" ] || echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

    ip route show table 100 2>/dev/null | grep -q '10.200.1.0/30' || ip route replace 10.200.1.0/30 dev veth-host table 100

    W=$(ip route get 8.8.8.8 2>/dev/null | $BB awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
    G=$(ip route get 8.8.8.8 2>/dev/null | $BB awk '{for (i=1;i<=NF;i++) if ($i=="via") {print $(i+1); exit}}')
    case "$W" in
        rmnet*|v4-rmnet*)
            if [ -n "$G" ]; then
                ip route replace default via "$G" dev "$W" table 100
            else
                ip route replace default dev "$W" table 100
            fi
            ip rule del pref 100 2>/dev/null
            ip rule del pref 101 2>/dev/null
            ip rule add from 10.200.1.0/30 lookup 100 pref 100
            ip rule add iif "$W" to 10.200.1.0/30 lookup main pref 101
            ;;
    esac
}

# Keep cpu7 offline and the battery in the 50-60% band.
[ -f /data/openwrt/scripts/service_power_guard.sh ] && sh /data/openwrt/scripts/service_power_guard.sh

# Optional headless power tuning (only when explicitly enabled).
if [ -f "/data/openwrt/enable_headless" ] && [ -f "/data/openwrt/scripts/05_headless_power_control.sh" ]; then
    sh /data/openwrt/scripts/05_headless_power_control.sh > /data/openwrt/logs/power.log 2>&1
fi

# Wait for Android to finish booting.
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 90 ]; do
    sleep 2
    i=$((i+1))
done

# Wait for the 5G IPv4 default route (mobile data up).
i=0
IF=""
while [ $i -lt 60 ]; do
    IF=$(ip route get 8.8.8.8 2>/dev/null | $BB awk '{for (j=1;j<=NF;j++) if ($j=="dev") {print $(j+1); exit}}')
    case "$IF" in
        rmnet*|v4-rmnet*) break ;;
    esac
    sleep 2
    i=$((i+1))
done
log "WAN interface: ${IF:-none}"

# Wait for the USB LAN NIC so the container gets its LAN port on first start.
i=0
while ! ip link show eth0 >/dev/null 2>&1 && [ $i -lt 30 ]; do
    sleep 2
    i=$((i+1))
done

if container_running; then
    log "container already running, skip"
else
    log "starting OpenWrt container (WAN=${IF:-none})"
    sh /data/openwrt/scripts/04_start_openwrt_and_network.sh >> "$LOG" 2>&1
    log "04 exit=$?"
fi

ensure_wan

# Watchdog: restart the container if it dies.  Remove the flag file to stop.
while true; do
    sleep 30
    [ -f /data/openwrt/disable_autorun ] && continue
    ensure_wan
    if ! container_running; then
        log "container not running, restarting"
        sh /data/openwrt/scripts/04_start_openwrt_and_network.sh >> "$LOG" 2>&1
        log "04 exit=$?"
    fi
done
