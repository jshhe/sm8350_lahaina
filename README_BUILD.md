# 一加9 Pro OpenWrt 内核构建与刷机指南

本目录的 GitHub Actions 工作流会构建：

1. **`AnyKernel3-OnePlus9Pro-OpenWrt-5.4.zip`**  
   带 OpenWrt 容器依赖 + Realtek RTL8156/RTL8156B 2.5G 驱动的 Linux 5.4.254 内核，用 **Kernel Flasher** 刷入。
2. **`r8152-2.5G-Magisk-Module.zip`**  
   原厂内核免刷机兜底方案：通过 Magisk 模块加载 `r8152 v2.22.1` 驱动（可选）。
3. **`Image` / `r8152_2p5g.ko` / `stock-config-used.txt`**  
   供校验与排查。

---

## 推荐顺序（重要）

**先做零刷机方案，再考虑自定义内核。**

1. **第一步：跑 `Build r8152 2.5G Module for Stock Kernel`**  
   产物是 `r8152-2.5G-Magisk-Module.zip`。在原厂内核 + Magisk 上安装这个模块，就能让原厂内核认 RTL8156/RTL8156B 2.5G 网卡。  
   **不刷内核、不改分区、零变砖风险**，5G 基带、显示、触控、充电全部保持原厂状态。

2. **第二步：用原厂内核 + OpenWrt 21.02 跑通 5G 软路由**  
   原厂内核已经具备 `NET_NS` / `VETH` / `BRIDGE` / `OVERLAY_FS` 和 IPv4 iptables；配合 `openwrt-21.02.7-armvirt-64-default-rootfs.tar.gz`（`fw3` + `iptables-legacy`）就能跑容器。  
   先用你现有的千兆网卡验证 5G WAN、LAN、DHCP、DNS、NAT 全部正常。

3. **第三步（可选/实验性）：再尝试自定义内核**  
   `Build OnePlus 9 Pro 5.4 Kernel (OpenWrt + RTL8156B)` 会打开 PID/IPC/USER 命名空间、nftables、IPv6 NAT66，并把 2.5G 驱动编进内核。  
   主内核 Kconfig 和 `OplusKernelEnvConfig.mk` 会保留 OPLUS 的调度/锁/内存/显示核心（工作流已设置 `BRAND_SHOW_FLAG=oneplus`，C 宏和结构体布局与 Stock 一致）；真正可能缺的是 `vendor/oplus` 里的厂商驱动/模块，以及预编译 `vendor_dlkm` 模块的 ABI 兼容性。**这是实验性路线，建议在原厂内核方案稳定后再试，并先备份 boot。**

---

## 一、这次构建的关键事实

| 项目 | 值 |
| :--- | :--- |
| 内核源码 | OnePlusOSS `oneplus/sm8350_u_14.0.0_oneplus9`（Linux 5.4.254） |
| 配置基线 | 从官方 `LE2120_14.0.0.1901` 的 `boot.img` 提取的**真实运行配置** |
| 编译器 | Android Clang **11.0.2 r383902b1**（与官方固件 `CONFIG_CC_VERSION_TEXT` 完全一致） |
| 2.5G 驱动 | Realtek 官方 `r8152` **v2.22.1**，支持 RTL8156 / RTL8156B / RTL8156BG |
| 内核 localversion | `-qgki-gd2a1055adeb0`（与官方 `5.4.254-qgki-gd2a1055adeb0` 对齐，尽量保持 vendor 模块兼容） |
| boot 镜像 | header v3，kernel 45.41 MiB，ramdisk 20.47 MiB（**AnyKernel3 必须保留 ramdisk**） |

### 原厂内核的真实能力

| 能力 | 原厂内核 | 说明 |
| :--- | :---: | :--- |
| `NET_NS` / `VETH` / `BRIDGE` / `OVERLAY_FS` | ✅ | 可做 veth + 容器 |
| `IP_NF_IPTABLES` / `IP_NF_NAT` / `MASQUERADE` | ✅ | IPv4 NAT 可用 |
| `MOUNT_NS` | ✅（`NAMESPACES=y`） | Linux 没有单独的 `MOUNT_NS` 配置项 |
| `PID_NS` / `IPC_NS` / `USER_NS` | ❌ | 原厂关闭；自定义内核开启 |
| `NF_TABLES`（fw4/nftables） | ❌ | 原厂只能 `fw3` + `iptables-legacy` |
| 原生 IPv6 同 /64 共享 | ✅ | 原厂内核即可，不需要 NAT66 |
| `DEVTMPFS` | ❌ | 容器必须 bind-mount `/dev` |
| `USB_RTL8152` | ✅ 但为 2019 年老驱动 | 只认 RTL8153 千兆，不认 RTL8156 2.5G |
| `USB_NET_CDC_NCM` | ❌ | 2.5G 网卡没有通用兜底 |

**结论**：
- **Track A（原厂内核）**：只能跑“降级的 IPv4 chroot” + 千兆网卡。先跑通这个，零刷机风险。
- **Track B（自定义内核）**：PID/IPC/USER 命名空间、nftables、RTL8156 2.5G 全部打开；原生 IPv6 在 Track A 就能做，不需要 NAT66。

---

## 二、把工程推到 GitHub

本地的 `kernel/`、`modules_and_devicetree/`、`firmware_LE2120_*/`、`payload.bin`、`output/`、`.tmp/`、`openwrt_rootfs/`、`toolchain/` 都已在 `.gitignore` 中排除。**不要把这些大文件推上去**；工作流会在云端自己克隆内核源码。

```powershell
cd C:\path\to\sm8350_lahaina
git init
git add .
git commit -m "OnePlus 9 Pro OpenWrt kernel build"
```

在 GitHub 新建一个仓库（Private 也可以），然后：

```powershell
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git branch -M main
git push -u origin main
```

推送前可以检查一下将要提交的文件大小：

```powershell
git ls-files | ForEach-Object { Get-Item $_ } | Sort-Object Length -Descending | Select-Object -First 20 Name, Length
```

---

## 三、触发云端编译

1. 打开 GitHub 仓库 → **Actions**；
2. 左侧选择 **Build OnePlus 9 Pro 5.4 Kernel (OpenWrt + RTL8156B)**；
3. 右侧 **Run workflow** → **Run workflow**；
4. 等待 30~90 分钟（首次要克隆内核 + 下载工具链 + LTO 编译）。

工作流会做这些事：

- 下载 Clang **r383902b1** + GCC 4.9 交叉工具链；
- 克隆 OnePlusOSS 内核源码；
- 克隆 `modules_and_devicetree`，把 `vendor`、`techpack`、`device` 覆盖进内核树，保持与官方源码布局一致；
- 用 `drivers/r8152/` 替换内核里的老 `r8152.c`；
- 以 `configs/stock_le2120_1901.config` 为基线，打开容器、netfilter、2.5G 选项；
- **强制校验**关键配置，缺一个就失败（避免刷进去才发现没开）；
- 编译 `Image`；
- 额外编译一个 `r8152_2p5g.ko` 给原厂内核做 Magisk 兜底；
- 打包 AnyKernel3 和 Magisk 模块。

产物在运行页最下方的 **Artifacts**：

```text
OnePlus9Pro-OpenWrt-Kernel-<run_number>
├── AnyKernel3-OnePlus9Pro-OpenWrt-5.4.zip
├── r8152-2.5G-Magisk-Module.zip
├── Image
├── r8152_2p5g.ko
└── stock-config-used.txt
```

---

## 四、刷入自定义内核（Track B，实验性）

> **建议先完成第五节的“原厂内核 + r8152 模块”方案**，确认 5G 和 OpenWrt 容器都正常后，再尝试本节。自定义内核缺少完整的 OPLUS 内置代码，属于实验性路线；刷之前务必用 `scripts/01_backup_partitions.sh` 备份，并确认电脑里有原厂 `boot.img`。

### 推荐：Kernel Flasher

1. 把 `AnyKernel3-OnePlus9Pro-OpenWrt-5.4.zip` 传到手机；
2. 打开 **Kernel Flasher**；
3. 选择该 zip → 刷入 → 重启。

AnyKernel3 会：

- 自动识别 A/B 槽位（`IS_SLOT_DEVICE=1`）；
- `dump_boot` 解包当前 `boot.img`；
- 替换其中的 kernel；
- `write_boot` 重新打包并写回。

**它保留原来的 20.47 MiB ramdisk，所以 Magisk 补丁不会掉。**

### 不要做的事

- **不要** `fastboot flash boot Image`：`Image` 只是内核二进制，不是 boot 镜像；
- **不要**用 `fastboot flash boot` 直接刷 AnyKernel3 的 zip；
- 如果你要刷原始 `boot.img`，必须先在备用机上用 Magisk 打好补丁。

### 刷完验证

```bash
adb shell uname -r
# 期望：5.4.254-qgki-gd2a1055adeb0

adb shell su -c "dmesg | grep -i r8152"
adb shell su -c "lsusb"
adb shell su -c "ip link"

# 插上 2.5G 网卡后：
adb shell su -c "dmesg | grep -iE 'r8152|rtl8156'"
adb shell su -c "ip -br link"
```

如果 2.5G 网卡被识别，`ip link` 里会出现 `eth0`（或 `usb0`），`dmesg` 会打印 `Realtek RTL8152/RTL8153 Based USB Ethernet Adapters v2.22.1`。

---

## 五、零刷机方案：原厂内核 + r8152 模块（推荐先做）

这是**首选方案**，也是 2.5G 驱动最安全的落地方式：

1. 在 GitHub Actions 里运行 **`Build r8152 2.5G Module for Stock Kernel`**；
2. 下载 `r8152-2.5G-Magisk-Module.zip`；
3. 传到手机，在 **Magisk App → 模块 → 从本地安装** 中选择该 zip；
4. 重启；
5. 插上 2.5G 网卡，检查：

```bash
adb shell su -c "lsmod | grep r8152"
adb shell su -c "dmesg | grep -i r8152"
adb shell su -c "ip -br link"
```

模块里的驱动名是 `r8152_2p5g`，不会和原厂内置的 `r8152` 冲突。原厂内置驱动不认 `0x8156`，所以新驱动能绑定 2.5G 网卡。

> 注意：这个兜底依赖内核符号 CRC 与 vermagic 完全匹配。如果 `insmod` 报
> `disagrees about version of symbol`，说明原厂内核的符号版本与我们的构建不一致，
> 这种情况只能用 Track B 的完整自定义内核。

---

## 六、部署 OpenWrt

### 6.1 选择 rootfs

| 路线 | rootfs | 防火墙 |
| :--- | :--- | :--- |
| Track A（原厂内核） | `openwrt-21.02.7-armvirt-64-default-rootfs.tar.gz` | `fw3` + `iptables-legacy` |
| Track B（自定义内核） | `openwrt-23.05.5-armsr-armv8-rootfs.tar.gz` | `fw4` + `nftables` |

两个包都已下载到本地的 `openwrt_rootfs/`。

### 6.2 推送到手机

`/data/adb` 不能直接 `adb push`，先推到 `/sdcard/` 再 `su` 复制：

```powershell
# 1) rootfs
adb push openwrt_rootfs\openwrt-21.02.7-armvirt-64-default-rootfs.tar.gz /sdcard/

# 2) 脚本
adb push scripts\03_setup_openwrt_rootfs.sh /sdcard/03_setup_openwrt_rootfs.sh
adb push scripts\04_start_openwrt_and_network.sh /sdcard/04_start_openwrt_and_network.sh
adb push service_openwrt_autorun.sh /sdcard/service_openwrt_autorun.sh

# 3) 复制到 root 可写目录并授权
adb shell su -c "mkdir -p /data/adb/openwrt /data/adb/service.d"
adb shell su -c "cp /sdcard/03_setup_openwrt_rootfs.sh /sdcard/04_start_openwrt_and_network.sh /data/adb/openwrt/"
adb shell su -c "cp /sdcard/service_openwrt_autorun.sh /data/adb/service.d/"
adb shell su -c "chmod 755 /data/adb/openwrt/*.sh /data/adb/service.d/service_openwrt_autorun.sh"
```

### 6.3 部署 rootfs

```bash
adb shell su -c "sh /data/adb/openwrt/03_setup_openwrt_rootfs.sh"
```

脚本会：

- 解压到 `/data/openwrt/rootfs`；
- 自动识别 21.02 / 23.05，选择 `option ifname` 或 `option device`；
- 写入 `lan`（192.168.2.1/24）、`wan`（10.200.1.2/30）、`wan6`；
- 写入 `firewall`（LAN→WAN 转发 + masq）和 `dhcp`；
- 用假 `modprobe` 绕过 OpenWrt 的 kmod 依赖（驱动已编进内核）。

### 6.4 启动容器与网络

```bash
adb shell su -c "sh /data/adb/openwrt/04_start_openwrt_and_network.sh"
```

脚本会：

- 用 `unshare` 创建 mount/UTS/net 命名空间（自定义内核额外加 PID/IPC）；
- bind-mount `/dev`、`/dev/pts`、`/sys`、`/proc`；
- 用 **Magisk BusyBox 的 `ip`** 把 USB 网卡移进容器 netns（Android toybox 的 `ip` 不支持 `netns`）；
- 创建 `veth-host` / `veth-owrt`，配置 10.200.1.1 ↔ 10.200.1.2；
- 用**数字路由表 100** 绕过 Android netd（不再使用错误的 `lookup rmnet_data0`）；
- 配置宿主机 `iptables` MASQUERADE 与 FORWARD；
- 自动优先使用 `v4-rmnet_data0`（IPv6-only 运营商的 clat 接口）。

启动后，电脑插网线到 USB 网卡，访问：

```text
http://192.168.2.1
```

### 6.5 开机自启

```bash
adb shell su -c "sh /data/adb/service.d/service_openwrt_autorun.sh &"
```

或者直接重启手机，Magisk 会执行 `/data/adb/service.d/` 下的脚本。服务脚本会：

- 等待 5G 数据接口拿到 IP；
- 如果容器没在跑，自动执行 `04`；
- 每 30 秒检查一次 `procd` 是否存活。

---

## 七、回滚

### 自定义内核刷失败 / 开不了机

1. 长按 **音量下 + 电源** 进 Fastboot；
2. 刷回原厂 boot：

```bash
fastboot flash boot firmware_LE2120_14.0.0.1901\boot.img
fastboot reboot
```

如果是 A/B 槽位问题：

```bash
fastboot getvar current-slot
fastboot flash boot_a firmware_LE2120_14.0.0.1901\boot.img
fastboot flash boot_b firmware_LE2120_14.0.0.1901\boot.img
```

3. 如果 Fastboot 也进不去，按 `RECOVERY_AND_ROLLBACK.md` 走 9008 救砖。

### Magisk 模块兜底失败

在 Magisk App → 模块 → 卸载 `OnePlus 9 Pro RTL8156B 2.5G USB NIC`，重启即可。它不会改分区。

---

## 八、已知限制与排错

1. **6GHz Wi-Fi 开不了**：一加9 Pro 全系没有 6GHz FEM/滤波器，FCC 也只认证到 5.85GHz；Root 改国家码无效。
2. **自定义内核属于实验性**：`CONFIG_OPLUS_*` 的主内核部分在 `init/Kconfig` 等主 Kconfig 里，`OplusKernelEnvConfig.mk` 会根据 `BRAND_SHOW_FLAG=oneplus` 定义 `OPLUS_FEATURE_*` C 宏；工作流已经设置该变量，所以 OPLUS 的调度/锁/内存/显示核心会保留，C 宏和结构体布局与 Stock 一致。真正可能缺的是 `vendor/oplus` 里的厂商驱动/模块（触控、快充、部分性能扩展），以及预编译 `vendor_dlkm` 模块的 ABI 兼容性。5G/USB/UFS/显示由主内核和 Qualcomm 驱动提供，通常可用；Wi-Fi/音频/相机/触控/快充这些模块可能报 vermagic/unknown symbol 错误。**生产环境优先用“原厂内核 + r8152 模块”**；自定义内核只作为打开 PID_NS/nftables 的实验路线。
3. **原生 IPv6 不需要 NAT66**：运营商 /64 通过同前缀转发/NDP 共享给 LAN；原厂内核也能做。NAT66 已从脚本移除。
4. **2.5G 网卡芯片**：推荐 RTL8156B/BG；初代 RTL8156 也能驱动但发热大；RTL8153/AX88179 千兆原厂内核就支持。
5. **`iptables` 后端**：原厂内核没有 nftables，宿主机必须用 `iptables-legacy`；`04` 脚本会自动检测并回退。
6. **Android netd 会重置规则**：如果发现断网，重新执行 `04`，或把 `service_openwrt_autorun.sh` 作为守护进程运行。
7. **首次开机慢**：内核带 LTO/CFI，首次启动可能比原厂慢几秒，正常。

---

## 九、构建失败时看哪里

GitHub Actions 运行页 → 失败的那一步 → 展开日志。重点看：

- `Prepare config`：哪个 `CONFIG_*` 没开；
- `Compile kernel Image`：第一个 `error:`；
- `Build out-of-tree r8152_2p5g.ko`：`insmod`/CRC 相关问题；
- `Package AnyKernel3`：`Image` 是否生成。

把失败日志发给我，我按具体错误改工作流。
