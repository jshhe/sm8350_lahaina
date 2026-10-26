# IPv6 设计说明：同 /64 原生共享，不用 NAT66

## 实测证据（2026-10-25，中国移动 5G + 热点）

插卡开热点后，手机侧：

```text
rmnet_data1: 2001:db8:1234:5678::a1b2/64    (5G 上游)
wlan2:       2001:db8:1234:5678::c1/64      (热点 AP)
client:      2001:db8:1234:5678::2/64       (下级设备)
```

> 注：上面的地址是文档示例前缀（RFC 3849 `2001:db8::/32`），
> 不是实测的真实运营商前缀。

- 三者是**同一个 /64**
- `ip6tables -t nat` 表根本不存在（原厂内核没有 IP6_NF_NAT）
- `dumpsys tethering` 显示 IPv6 由 **BPF/硬件 offload** 在 `rmnet_data1` 和
  `wlan2` 之间转发，客户端源地址保持不变
- 下级 `test-ipv6.com` 10/10 通过

结论：Android 热点没有做 NAT66，而是把运营商的 /64 同时放在上游和 AP 上，
按客户端地址做转发。我们的 OpenWrt 容器也应该这样做。

## 另一个关键修正

活动 5G 接口是 **`rmnet_data1`**，不是 `rmnet_data0`：

```text
rmnet_data0: 只有 link-local，没有 IPv4/IPv6 全局地址
rmnet_data1: 10.x.x.x/28 + 2001:db8:1234:5678:.../64 + 默认路由
```

`04_start_openwrt_and_network.sh` 已改为用 `ip route get 8.8.8.8` 选择
真正承载默认路由的接口，避免选到空的 `rmnet_data0`。

## 当前实现（04 脚本）

1. 从 `rmnet_data1` 读取全局 `/64`
2. 容器 LAN `eth0` 配同 /64 的 `...::1/64`
3. 容器 `veth-owrt` 用 `fe80::2`，默认路由指向宿主 `veth-host` 的 `fe80::1`
4. 宿主加策略路由：
   - `ip -6 rule add iif rmnet_data1 lookup 200 pref 1000`
   - `table 200: 2409:...::/64 dev veth-host`
   - 宿主自己的 /64 地址由 `local` 表（rule 0）优先命中
5. 容器内 `odhcpd` 在 `eth0` 发 RA，客户端 SLAAC 拿到同 /64 地址
6. 不做 NAT66、不使用 ULA

## 还需要实测的点

- 下级客户端能否通过 OpenWrt 正常拿到 `2409:...` 地址并上网
- 运营商是否接受该 /64 内其他源地址（Android 热点已证明可以）
- 如果运营商对每个地址做 NDP，需要在 `rmnet_data1` 上补 proxy NDP
  （Android 用 offload，不需要内核 proxy；我们先按路由转发验证）

## 结论

- NAT66 已从 `03`/`04` 删除
- 原生 IPv6 不依赖 `IP6_NF_NAT`，**原厂内核也能做**
- 自定义内核的 IPv6 NAT66 选项不再是必需项；它现在只用于 PID_NS/nftables/fw4
