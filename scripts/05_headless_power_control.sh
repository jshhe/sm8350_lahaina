#!/system/bin/sh
# ==============================================================================
# 05_headless_power_control.sh
# 手机端执行：无头化精简服务、能耗温控压制与电池停充保护
# ==============================================================================

echo "[1/4] 彻底关闭屏幕背光与图形渲染..."
if [ -e "/sys/class/backlight/panel0-backlight/brightness" ]; then
    echo 0 > /sys/class/backlight/panel0-backlight/brightness
fi

# 停止渲染与无用多媒体服务
stop surfaceflinger 2>/dev/null || true
stop bootanim 2>/dev/null || true
stop audioserver 2>/dev/null || true
stop cameraserver 2>/dev/null || true
stop media 2>/dev/null || true
stop drm 2>/dev/null || true
stop bluetooth 2>/dev/null || true

echo "[2/4] CPU/电池守护（X1 离线 + 50~60% 停充）..."
if [ -x /data/openwrt/scripts/05b_cpu_charge_guard.sh ]; then
    sh /data/openwrt/scripts/05b_cpu_charge_guard.sh --once
else
    echo "[!] 05b_cpu_charge_guard.sh 不存在，跳过"
fi

echo "[3/4] 锁定内核唤醒锁（防止系统深度睡眠挂起软路由与网络）..."
echo "openwrt_router" > /sys/power/wake_lock

echo "[4/4] 无头化完成。电池与 CPU 由 05b 常驻守护持续维持。"

echo "[✓] 无头化与功耗温控压制完成！当前在线核心: $(cat /sys/devices/system/cpu/online)"
