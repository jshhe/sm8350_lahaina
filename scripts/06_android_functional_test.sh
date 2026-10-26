#!/system/bin/sh
# Functional acceptance test for the custom kernel (Android side).
echo "=== kernel ==="
uname -r
uname -v
echo "boot_completed=$(getprop sys.boot_completed)"

echo "=== root / pidns ==="
/data/adb/magisk/busybox unshare -p -f sh -c 'echo pid_inside_ns=$$' 2>&1
echo "pidns_rc=$?"

echo "=== popup ==="
dumpsys window 2>/dev/null | grep -E "mCurrentFocus"
echo "system_error_windows=$(dumpsys window windows 2>/dev/null | grep -c 'ty=SYSTEM_ERROR')"
echo "updatable_crashing=$(getprop sys.init.updatable_crashing) name=$(getprop sys.init.updatable_crashing_process_name)"

echo "=== hal services ==="
for s in zygote surfaceflinger fps_hal vendor.audio-hal bluetooth camera-provider-aidl media.camera; do
  echo "init.svc.$s=$(getprop init.svc.$s)"
done
echo "camera_provider=$(getprop init.svc.camera-provider-2-7) $(getprop init.svc.camera-provider-aidl)"

echo "=== modules ==="
for m in msm_drm wlan camera rmnet_core r8152 pinctrl_lahaina; do
  if [ -d /sys/module/$m ]; then echo "$m=present refcnt=$(cat /sys/module/$m/refcnt 2>/dev/null)"; else echo "$m=absent"; fi
done
echo "lsmod_count=$(lsmod | wc -l)"

echo "=== fingerprint driver ==="
ls -l /dev/goodix_fp /dev/oplus_fp_common 2>&1
echo "gf_qcom=$(cat /sys/module/gf_qcom/refcnt 2>&1)"
ls /sys/bus/platform/drivers/ 2>/dev/null | grep -i -E "fp|goodix" | head

echo "=== network ==="
ip -br link | grep -E "eth0|wlan0|rmnet_data"
echo "--- rmnet addrs ---"
ip -o -4 addr show | grep rmnet
echo "--- default route ---"
ip route get 8.8.8.8 2>&1 | head -2
echo "--- wifi ---"
cmd wifi status 2>/dev/null | head -5

echo "=== usb net drivers ==="
ls /sys/bus/usb/drivers/ 2>/dev/null | grep -E "r8152|cdc_ncm|aqc111|ax88179" 
echo "r8152_builtin=$(grep -c r8152 /proc/kallsyms 2>/dev/null)"

echo "=== display / audio ==="
dumpsys display 2>/dev/null | grep -m1 -E "mDisplayState|DisplayDeviceInfo"
dumpsys audio 2>/dev/null | grep -m2 -E "Audio HAL|mMode|Devices:"

echo "=== power guard ==="
echo "cap=$(cat /sys/class/oplus_chg/battery/capacity) mmi=$(cat /sys/class/oplus_chg/battery/mmi_charging_enable)"
echo "cpu7_online=$(cat /sys/devices/system/cpu/cpu7/online) cpu0_cur=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)"

echo "=== bluetooth ==="
getprop init.svc.bluetooth
dumpsys bluetooth_manager 2>/dev/null | grep -m2 -E "enabled:|state:"

echo "=== 5g data ping ==="
ping -c 2 -W 3 223.5.5.5 2>&1 | tail -3
