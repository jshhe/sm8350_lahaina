#!/system/bin/sh
# ==============================================================================
# 01_backup_partitions.sh
# 手机端执行：全量备份一加9 Pro（SM8350）关键引导与基带分区
# 请在 ADB Shell 中切换至 root 权限后执行：su -c "sh /sdcard/01_backup_partitions.sh"
# ==============================================================================

set -e

BACKUP_DIR="/sdcard/op9p_backup"
mkdir -p "$BACKUP_DIR"

SLOT=$(getprop ro.boot.slot_suffix | tr -d '_')
if [ -z "$SLOT" ]; then
    SLOT="a"
fi

echo "=========================================="
echo "当前活动槽位: Slot $SLOT"
echo "备份输出目录: $BACKUP_DIR"
echo "=========================================="

backup_part() {
    NAME=$1
    DEV="/dev/block/by-name/$NAME"
    OUT="$BACKUP_DIR/${NAME}.img"
    if [ -e "$DEV" ]; then
        echo "[+] 正在备份: $NAME -> $OUT ..."
        if dd if="$DEV" of="$OUT" bs=4096 2>/dev/null; then
            sync
            echo "[+] 完成: $NAME"
        else
            echo "[!] 失败: $NAME"
            return 1
        fi
    else
        echo "[-] 跳过不存在的分区: $NAME"
    fi
}

# 1. 核心引导与内核分区
backup_part "boot_${SLOT}"
backup_part "vendor_boot_${SLOT}"
backup_part "dtbo_${SLOT}"
backup_part "vbmeta_${SLOT}"
backup_part "vbmeta_system_${SLOT}"

# 2. 关键基带射频校准与 IMEI 分区 (重要!)
backup_part "modemst1"
backup_part "modemst2"
backup_part "fsg"
backup_part "fsc"
backup_part "persist"

sync
echo "[+] 生成 SHA256 校验文件 ..."
(cd "$BACKUP_DIR" && sha256sum *.img > SHA256SUMS.txt)

echo "=========================================="
echo "备份完成！"
echo "说明：这里的 boot 是当前已打 Magisk 补丁的引导镜像；"
echo "      纯净原厂 boot.img 已保存在电脑的 firmware_LE2120_14.0.0.1901/boot.img。"
echo "请立即在电脑端命令行执行以下命令拉取备份到电脑："
echo "adb pull $BACKUP_DIR ./stock_backup_pc"
echo "=========================================="
