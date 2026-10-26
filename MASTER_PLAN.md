# 一加9 Pro (SM8350) 运行 OpenWrt 5G 软路由：万全之策执行手册

> **2026-10 更新（重要）**：优先执行 `README_BUILD.md` 的“零刷机方案”——**原厂内核 + `r8152` Magisk 模块 + OpenWrt 21.02**。原厂内核已具备 `NET_NS` / `VETH` / `BRIDGE` / `OVERLAY_FS` 与 IPv4 iptables，足以跑通 5G 软路由；2.5G 驱动通过 Magisk 模块加载。自定义内核（PID_NS/nftables/IPv6 NAT66 + 2.5G 内置）作为**实验性第二步**，下文阶段 2 的“必须编译内核”已不再是首选。

本文档为你量身定制全套“防变砖、零风险、高可用”的落地闭环方案。手机到手后，按照本手册的阶段性检查清单（Checklist）操作，每一步都有验证指标和回滚逃生通道。

---

## 一、 硬件与外设准备清单（手机到手前准备）

要实现“7×24小时稳定 5G CPE + 2.5G 软路由”，外设选型至关重要：

| 硬件设备 | 推荐型号 / 参数要求 | 避坑指南 |
| :--- | :--- | :--- |
| **Type-C 扩展坞** | 支持 **PD 100W/65W 供电输入** + 至少 1 个 **USB 3.0 (5Gbps)** 口 | 必须支持边供电边传输数据（PD Passthrough）；不要买劣质百兆小扩展坞，高通 DWC3 跑满 2.5G 需要 USB 3.0 带宽。 |
| **USB 2.5G 网卡** | 芯片务必选用 **Realtek RTL8156B / RTL8156BG** | 兼容性最好，发热低。避免买到老旧的 RTL8156（初代无 B），初代发热大容易断流。ASIX AX88179A（千兆）亦可。 |
| **充电头与数据线** | 30W~65W 标准 PD 协议充电头 + C-to-C 优质线缆 | 避免使用魔改私有快充协议（如非标准 65W/80W VOOC/WARP 直充头），建议使用通用 PD 协议让扩展坞握手 5V/9V 供电。 |
| **散热措施（可选）** | 磁吸半导体散热背夹 或 弱电箱 5V 静音小风扇 | 虽已关停超大核并锁频，但夏季 7×24 小时密闭工作时，加微风散热可保基带射频寿命。 |
| **SIM 卡与网络** | 5G 手机卡，开通 SA 模式与 VoLTE | 建议关闭移动数据漫游限制，确认 APN 设置。 |

---

## 二、 全流程五大阶段路线图（按部就班）

```text
[手机到手]
   │
   ├─► 阶段 1：验机、固化底包、解锁 BL、获取 Root 权限并全量备份关键分区（安全底线）
   │
   ├─► 阶段 2：编译魔改 Linux 5.4 原厂内核（内置容器、Netfilter、全静态 2.5G 网卡驱动）
   │
   ├─► 阶段 3：部署纯用户空间 OpenWrt Rootfs（免编大源码，配置 fw3/iptables 与伪装驱动）
   │
   ├─► 阶段 4：直通 eth0 物理网卡与注入 veth 绕过安卓 netd 策略路由（打通内外网）
   │          【优先在保留安卓完整图形界面下调试，通过屏幕实时监控 5G/基带/Termux】
   │
   └─► 阶段 5：验证 100% 成功后，按需开启无头化精简与电池停充（随时可通过脚本一键恢复图形界面）
```

---

## 三、 本目录已为你准备好的工具箱（即拿即用）

所有中间产物与执行脚本均保存在本项目根目录或 `scripts/` 子目录下：

1. **`MASTER_PLAN.md`**：本全局路线指南。
2. **`RECOVERY_AND_ROLLBACK.md`**：救砖与紧急回滚手册（包含 9008 救砖与 Fastboot 恢复）。
3. **`scripts/01_backup_partitions.sh`**：手机端一键备份 `boot`、`vendor_boot`、`dtbo`、`modem` 分区脚本。
4. **`scripts/02_patch_kernel_config.py`**：一键将容器与软路由配置合入内核 `defconfig` 的脚本。
5. **`scripts/03_setup_openwrt_rootfs.sh`**：在手机 `/data/openwrt` 自动解压并完成适配的脚本。
6. **`scripts/04_start_openwrt_and_network.sh`**：自动启动容器、直通物理网卡、注入策略路由的主网关脚本（**完全不影响屏幕与 UI**）。
7. **`scripts/05_headless_power_control.sh`**：熄屏、关渲染、离线 X1 超大核、限频、限充的温控脚本（生产服役模式）。
8. **`scripts/06_restore_gui.sh`**：一键恢复安卓图形界面（点亮屏幕、启动合成器、恢复触控）。
9. **`service_openwrt_autorun.sh`**：放在 `/data/openwrt/scripts/`，由唯一的 Magisk 入口 `/data/adb/service.d/00_openwrt.sh` 调用；负责开机自启、看门狗和 `ip_forward` 重断言。
10. **`manifest_android14.xml` / `build.config.lemonadep` / `fix_op9p_build_errors.patch`**：官方内核源码构建配置与修复补丁。
