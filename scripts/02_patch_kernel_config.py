#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
02_patch_kernel_config.py
用于自动修补一加9 Pro（SM8350）内核 defconfig 配置文件：
1. 开启 Namespaces & Cgroups 容器依赖
2. 开启 VETH、Bridge、TUN 等虚拟网络与二层交换
3. 开启全量 Netfilter、IPTables、NAT66 与 TPROXY
4. 开启 RTL8152 (2.5G) / AQC111 / AX88179 外置 USB 网卡驱动（全静态 =y）

默认以原厂 1901 固件提取的 configs/stock_le2120_1901.config 为基线，
输出到 configs/stock_le2120_1901.openwrt.config，不覆盖原厂基线。
"""

import sys
import os
import shutil

REQUIRED_CONFIGS = {
    # 容器核心依赖：Namespaces & Cgroups
    "CONFIG_NAMESPACES": "y",
    "CONFIG_UTS_NS": "y",
    "CONFIG_IPC_NS": "y",
    "CONFIG_USER_NS": "y",
    "CONFIG_PID_NS": "y",
    "CONFIG_NET_NS": "y",
    "CONFIG_CGROUPS": "y",
    "CONFIG_CGROUP_DEVICE": "y",
    "CONFIG_CGROUP_PIDS": "y",
    "CONFIG_CGROUP_CPUACCT": "y",
    "CONFIG_CGROUP_SCHED": "y",
    "CONFIG_MEMCG": "y",
    "CONFIG_CPUSETS": "y",
    "CONFIG_DEVTMPFS": "y",
    "CONFIG_SYSVIPC": "y",
    "CONFIG_POSIX_MQUEUE": "y",
    "CONFIG_OVERLAY_FS": "y",
    
    # 虚拟网络与交换
    "CONFIG_VETH": "y",
    "CONFIG_BRIDGE": "y",
    "CONFIG_BRIDGE_NETFILTER": "y",
    "CONFIG_MACVLAN": "y",
    "CONFIG_VLAN_8021Q": "y",
    "CONFIG_TUN": "y",
    
    # 防火墙、NAT、NAT66 与 TPROXY
    "CONFIG_NETFILTER": "y",
    "CONFIG_NETFILTER_ADVANCED": "y",
    "CONFIG_NF_CONNTRACK": "y",
    "CONFIG_NF_TABLES": "y",
    "CONFIG_NF_TABLES_INET": "y",
    "CONFIG_NF_TABLES_IPV4": "y",
    "CONFIG_NF_TABLES_IPV6": "y",
    "CONFIG_NFT_NAT": "y",
    "CONFIG_NFT_MASQ": "y",
    "CONFIG_NFT_TPROXY": "y",
    "CONFIG_NFT_SOCKET": "y",
    "CONFIG_NFT_COMPAT": "y",
    "CONFIG_NETFILTER_XT_TARGET_TPROXY": "y",
    "CONFIG_NETFILTER_XT_MATCH_SOCKET": "y",
    "CONFIG_NETFILTER_XT_MATCH_STATE": "y",
    "CONFIG_IP_NF_IPTABLES": "y",
    "CONFIG_IP_NF_FILTER": "y",
    "CONFIG_IP_NF_TARGET_REJECT": "y",
    "CONFIG_IP_NF_NAT": "y",
    "CONFIG_IP_NF_TARGET_MASQUERADE": "y",
    "CONFIG_IP6_NF_IPTABLES": "y",
    "CONFIG_IP6_NF_FILTER": "y",
    "CONFIG_IP6_NF_NAT": "y",
    "CONFIG_IP6_NF_TARGET_MASQUERADE": "y",
    
    # 外置 USB 网卡驱动（静态写入内核，防止 kmod 不匹配）
    "CONFIG_USB_NET_DRIVERS": "y",
    "CONFIG_USB_RTL8152": "y",
    "CONFIG_USB_NET_CDC_NCM": "y",
    "CONFIG_USB_NET_AQC111": "y",
    "CONFIG_USB_NET_AX88179_178A": "y",
}

def patch_config(config_path):
    if not os.path.exists(config_path):
        print(f"[!] 找不到配置文件: {config_path}")
        return False
    
    with open(config_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    
    existing = {}
    cleaned_lines = []
    for line in lines:
        stripped = line.strip()
        matched = False
        for key in REQUIRED_CONFIGS.keys():
            if stripped.startswith(f"{key}=") or stripped.startswith(f"# {key} is not set"):
                matched = True
                break
        if not matched:
            cleaned_lines.append(line)
            
    # 追加标准配置
    cleaned_lines.append("\n# === Added for OpenWrt Soft Router & Container Support ===\n")
    for k, v in REQUIRED_CONFIGS.items():
        if v == "y":
            cleaned_lines.append(f"{k}=y\n")
        elif v == "n":
            cleaned_lines.append(f"# {k} is not set\n")
        else:
            cleaned_lines.append(f"{k}={v}\n")
            
    with open(config_path, "w", encoding="utf-8") as f:
        f.writelines(cleaned_lines)
        
    print(f"[✓] 成功修补内核配置: {config_path}")
    print(f"    共注入/修正 {len(REQUIRED_CONFIGS)} 项内核功能特性。")
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target = sys.argv[1]
    else:
        target = "configs/stock_le2120_1901.openwrt.config"
        src = "configs/stock_le2120_1901.config"
        if not os.path.exists(target) and os.path.exists(src):
            os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
            shutil.copyfile(src, target)
            print(f"[i] 已从 {src} 复制基线到 {target}")
    patch_config(target)
