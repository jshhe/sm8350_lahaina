#!/system/bin/sh
# ==============================================================================
# 01b_full_backup_all_partitions.sh
# OnePlus 9 Pro (LE2120) full partition-level backup.
#
# Dumps every entry in /dev/block/by-name except `userdata` to $OUT.
# userdata is skipped because it is 221 GiB and lives on the same storage we
# are writing to; back it up separately at the file level if needed.
#
# Run as root:
#   adb push scripts/01b_full_backup_all_partitions.sh /data/local/tmp/
#   adb shell "su < /data/local/tmp/01b_full_backup_all_partitions.sh"
# ==============================================================================

OUT="${OUT:-/data/local/tmp/fullbackup}"
mkdir -p "$OUT"

# Refuse to start if /data does not have at least 16 GiB free.
AVAIL_KB=$(df -k /data 2>/dev/null | awk 'NR==2 {print $4}')
if [ -n "$AVAIL_KB" ] && [ "$AVAIL_KB" -lt 16777216 ]; then
    echo "[!] Not enough free space in /data: $((AVAIL_KB / 1024 / 1024)) GiB"
    exit 1
fi

FAIL=0
OK=0

echo "=============================================="
echo " Full partition backup"
echo " Output : $OUT"
echo " Started: $(date)"
echo "=============================================="

for d in /dev/block/by-name/*; do
    name=${d##*/}
    case "$name" in
        # userdata is 221 GiB and lives on the same storage we write to.
        # sda..sdf are WHOLE DISKS, not partitions: dumping them writes the
        # entire UFS (hundreds of GiB) and will fill /data.
        userdata|sda|sdb|sdc|sdd|sde|sdf)
            echo "[-] skip $name"
            continue
            ;;
    esac

    rm -f "$OUT/$name.img"
    if dd if="$d" of="$OUT/$name.img" bs=4M 2>/dev/null; then
        echo "[+] $name"
        OK=$((OK + 1))
    else
        echo "[!] FAILED $name"
        rm -f "$OUT/$name.img"
        FAIL=$((FAIL + 1))
    fi
done

sync

# Record device state next to the images.
getprop > "$OUT/getprop.txt" 2>/dev/null
ls -l /dev/block/by-name > "$OUT/by-name.txt" 2>/dev/null
cat /proc/partitions > "$OUT/proc_partitions.txt" 2>/dev/null

cd "$OUT" || exit 1
echo "[*] generating SHA256SUMS.txt ..."
sha256sum *.img > SHA256SUMS.txt
ls -l *.img > FILELIST.txt 2>/dev/null
sync

echo "=============================================="
echo " Done: $(date)"
echo " OK=$OK  FAILED=$FAIL"
echo " Total: $(du -sh "$OUT" 2>/dev/null | awk '{print $1}')"
echo " Now pull it from the PC:"
echo "   adb pull $OUT ./full_backup_LE2120"
echo "=============================================="
