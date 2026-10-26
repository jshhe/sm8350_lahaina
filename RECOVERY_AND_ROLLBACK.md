# 一加9 Pro 救砖与紧急回滚手册 (RECOVERY & ROLLBACK)

只要严格遵守本手册的备份准则，**你不可能将一加9 Pro 彻底变砖**。针对可能遇到的所有异常，我们设立了三级逃生通道。

---

## 逃生通道概览

| 故障级别 | 故障现象 | 应急方案 | 预计恢复耗时 |
| :--- | :--- | :--- | :--- |
| **Level 1 (轻微)** | 刷入自编译内核后卡第一屏、无限重启 | **Fastboot 刷回原厂备份的 `boot.img`** 或切 A/B 槽位 | 1 分钟 |
| **Level 2 (中度)** | Wi-Fi 变灰、5G 基带未识别、无法拨号 | **Fastboot 刷回原厂 `vendor_boot` 与 `dtbo`** | 2 分钟 |
| **Level 3 (终极)** | 黑屏、彻底无法进 Fastboot/Recovery（俗称真砖） | **进入高通 9008 端口（EDL 模式），使用 MSM 工具一键线刷** | 5 分钟 |

---

## 一、 第一道防线：手机刚到手时的“保命备份”

手机解锁 Bootloader 并获取临时 Root 权限后，**在做任何改动前，必须执行以下备份**。

运行本目录准备好的脚本 `scripts/01_backup_partitions.sh`，或手动在 ADB Shell (Root) 中执行：

```bash
mkdir -p /sdcard/stock_backup
# 1. 备份当前活动的 boot 引导镜像
dd if=/dev/block/by-name/boot_$(getprop ro.boot.slot_suffix | tr -d '_') of=/sdcard/stock_backup/boot.img
# 2. 备份 vendor_boot 分区
dd if=/dev/block/by-name/vendor_boot_$(getprop ro.boot.slot_suffix | tr -d '_') of=/sdcard/stock_backup/vendor_boot.img
# 3. 备份 dtbo 设备树分区
dd if=/dev/block/by-name/dtbo_$(getprop ro.boot.slot_suffix | tr -d '_') of=/sdcard/stock_backup/dtbo.img
# 4. 备份基带射频校准重要分区 (EFS: modemst1 / modemst2 / fsg)
dd if=/dev/block/by-name/modemst1 of=/sdcard/stock_backup/modemst1.img
dd if=/dev/block/by-name/modemst2 of=/sdcard/stock_backup/modemst2.img
dd if=/dev/block/by-name/fsg of=/sdcard/stock_backup/fsg.img
```
执行完毕后，立即在电脑端拉取到本地保存：
```bash
adb pull /sdcard/stock_backup ./stock_backup_pc
```

---

## 二、 Level 1 & 2 回滚：Fastboot 快速急救

如果刷入新编译的内核后卡开机第一屏（Bootloop）：

1. **进入 Fastboot 模式**：
   - 长按 `电源键 + 音量减` 强制关机，随后长按 `音量加 + 音量减 + 电源键` 直至进入 Fastboot 绿色机器人界面。
2. **刷回官方原厂镜像**：
   ```bash
   fastboot flash boot stock_backup_pc/boot.img
   fastboot flash vendor_boot stock_backup_pc/vendor_boot.img
   fastboot flash dtbo stock_backup_pc/dtbo.img
   fastboot reboot
   ```
   重启后系统将 100% 恢复至修改前的正常工作状态。

3. **双槽位一键切换技巧**：
   如果你之前将内核刷在 `slot B`，原厂仍在 `slot A`，可直接切换活动槽位秒级回退：
   ```bash
   fastboot --set-active=a
   fastboot reboot
   ```

---

## 三、 Level 3 终极底牌：高通 9008 (EDL) 模式一键救砖

一加9 Pro（SM8350）拥有高通芯片级硬件底层刷机通道（Qualcomm HS-USB QDLoader 9008）。即便分区表彻底损坏、AB 槽全部瘫痪，也能直接通过 9008 满血复活。

### 准备材料（手机到手前可提前在电脑下载备用）：
1. **高通 9008 USB 驱动**（Qualcomm USB Driver）。
2. **一加9 Pro 专用 MSM Download Tool 救砖线刷包**（对应机型：LE2120 国行 / LE2121 印度版 / LE2123 欧版）。
   - 可在各大安卓开发者论坛（酷安、大侠阿木工具箱、XDA）直接下载免认证版。

### 救砖步骤：
1. 电脑打开 **MSM Download Tool**，Target 选择 Other / User。
2. 手机完全关机。
3. 按住手机 **`音量加 + 音量减`** 不放，用原装 USB 线连接电脑。
4. 电脑设备管理器识别出 `Qualcomm HS-USB QDLoader 9008 (COMx)` 端口，MSM 工具出现 `Connected` 提示。
5. 点击 `Start`，约 3~5 分钟后整机底层分区全部由工厂固件重新写入，手机自动开机复活。
