#!/system/bin/sh
# ==============================================================================
# 06_restore_gui.sh
# 手机端执行：随时一键恢复安卓图形界面（点亮屏幕、启动合成器与界面）
# 适用于：需要使用手机屏幕排错、使用 Network Signal Guru 查看 5G 频段、调试应用等
# ==============================================================================

echo "[1/3] 恢复屏幕背光与供电..."
if [ -e "/sys/class/backlight/panel0-backlight/brightness" ]; then
    echo 150 > /sys/class/backlight/panel0-backlight/brightness
fi

echo "[2/3] 启动图形合成器与系统界面..."
start surfaceflinger 2>/dev/null || true
start bootanim 2>/dev/null || true

# 恢复系统 UI 与桌面
pm enable com.android.systemui 2>/dev/null || true
pm enable com.android.launcher 2>/dev/null || true

echo "[3/3] 恢复多媒体与外设服务..."
start audioserver 2>/dev/null || true
start media 2>/dev/null || true
start drm 2>/dev/null || true

# 移除开机无头化标志位
rm -f /data/openwrt/enable_headless 2>/dev/null || true

echo "[✓] 安卓图形界面已完全恢复！你现在可以正常通过屏幕触控操作手机。"
