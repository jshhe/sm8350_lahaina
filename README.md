# 一加9 Pro (OnePlus 9 Pro / SM8350 / lahaina / lemonadep) Linux 5.4 原厂内核源码全景调研

本文档汇总了一加官方（OnePlusOSS）关于一加9 Pro（代号：lemonadep，处理器：高通骁龙888 / SM8350 / Lahaina）各系统版本的 Linux 5.4 原厂开源内核代码库、分支对应关系、工程目录结构与编译指南。

---

## 1. 官方开源核心仓库

一加官方在 GitHub 组织 [OnePlusOSS](https://github.com/OnePlusOSS) 下开源了 SM8350 系列的代码。对于一加9 Pro，主要涉及以下三个仓库：

| 仓库名称 | 地址 | 适用系统版本 | 说明 |
| :--- | :--- | :--- | :--- |
| **android_kernel_oneplus_sm8350** | `https://github.com/OnePlusOSS/android_kernel_oneplus_sm8350` | Android 11 ~ 14 | Linux 5.4 主内核树源码（约 1.5 GB） |
| **android_kernel_modules_and_devicetree_oneplus_sm8350** | `https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8350` | Android 12.1 ~ 14 | 厂商驱动模块、Oplus私有驱动与设备树（约 127 MB） |
| **android_vendor_qcom_opensource_audio_kernel_sm8350** | `https://github.com/OnePlusOSS/android_vendor_qcom_opensource_audio_kernel_sm8350` | Android 11 | 高通开源音频内核模块（Android 12+ 已合并入 modules 仓库） |

> **注意关于 `kernel_manifest`**：  
> 一加新版统一清单仓库 `OnePlusOSS/kernel_manifest` 仅支持从骁龙8 Gen 1（SM8450）及更新的机型（采用 Bazel 构建系统）。**SM8350 不在 `kernel_manifest` 中**，其采用的是传统的 Google / 高通 `build/build.sh` 脚本和 Makefile 体系。

---

## 2. 一加9 Pro 分支与内核小版本对照表

一加9 Pro（国行 LE2120、印度版 LE2121、欧版 LE2123、美版 LE2125/LE2127）全生命周期内均基于 **Linux 5.4**（高通 GKI v1 架构），随着各代系统升级，内核小版本演进如下：

| Android / 系统版本 | 推荐检出分支 | 内核子版本 | 对应机型 / 标志性 Commit |
| :--- | :--- | :--- | :--- |
| **Android 14 (OOS / ColorOS 14)** | `oneplus/sm8350_u_14.0.0_oneplus9` | **Linux 5.4.254** | 支持 LE2120 / LE2121 / LE2123 / LE2127 (最新代码，2025年末同步) |
| **Android 13.1 (OOS 13.1)** | `oneplus/sm8350_t_13.1.0_oneplus9` | **Linux 5.4.210** | 支持 LE2111 / LE2121_13.1.0.9 |
| **Android 13.0 (OOS 13.0)** | `oneplus/sm8350_t_13.0.0_op9` | **Linux 5.4.147** | 支持 LE2111 / LE2121_11_F.21 |
| **Android 12.1 (OOS 12.1)** | `oneplus/sm8350_s_12.1_op9` | **Linux 5.4.147** | 支持 LE2121_11.C.61 / LE2111_11.C.61 |
| **Android 12.0 (OOS 12.0)** | `oneplus/SM8350_S_12.0_9Pro` | **Linux 5.4.86** | 专为 9 Pro 发布的 C.44 早期分支 |
| **Android 11 (OOS 11 / 出厂)** | `oneplus/SM8350_R_11.0` | **Linux 5.4.61** | 一加9 / 9Pro 初始出厂版本 (OxygenOS 11.2.1.1 ~ 11.2.10.10) |

> 📌 **推荐**：如果要编译当前最新的稳定内核（用于 KernelSU / SUSFS / 自定义内核），建议选择 `oneplus/sm8350_u_14.0.0_oneplus9` 分支。

---

## 3. 代码架构与目录链接关系 (以 Android 12+ / 14 为例)

自 Android 12.1 欧加（OPPO / OnePlus）体系整合后，内核被拆分为两大部分：

1. 主内核目录：`kernel/msm-5.4`（克隆自 `android_kernel_oneplus_sm8350`）
2. 根目录与驱动：克隆自 `android_kernel_modules_and_devicetree_oneplus_sm8350`
   并在根目录建立软链接：
   ```bash
   kernel/msm-5.4/drivers/staging/fw-api -> vendor/qcom/opensource/wlan/fw-api
   kernel/msm-5.4/drivers/staging/qcacld-3.0 -> vendor/qcom/opensource/wlan/qcacld-3.0
   kernel/msm-5.4/drivers/staging/qca-wifi-host-cmn -> vendor/qcom/opensource/wlan/qca-wifi-host-cmn
   kernel/msm-5.4/drivers/staging/utils -> vendor/qcom/opensource/wlan/utils
   ```
3. 构建系统：来自 AOSP 的 `kernel/build` 脚本环境。

---

## 4. 关键编译工具链与环境

- **编译器**：Google prebuilt Clang `clang-r416183b` (或更新的兼容 Linux 5.4 的 Clang-12 / Clang-14)
- **GCC 交叉编译器**：
  - `aarch64-linux-android-4.9`
  - `arm-linux-androideabi-4.9`
- **构建命令**：
  ```bash
  BUILD_CONFIG=kernel/msm-5.4/build.config.lemonadep \
  VARIANT=qgki \
  LLVM=1 \
  LLVM_IAS=1 \
  build/build.sh -j$(nproc)
  ```

---

## 5. 本目录附带的辅助文件

- `manifest_android14.xml`：标准的 Google Repo 清单文件，可直接用于 `repo init` 完整拉取一加9 Pro Android 14 (Linux 5.4.254) 内核及其关联驱动与工具链。
- `build.config.lemonadep`：一加9 Pro 专用的 build.config 配置文件。
- `fix_op9p_build_errors.patch`：社区验证过的编译报错修复补丁（解决部分 C 语言头文件规范、函数空参数警告等报错）。
- `fetch_kernel.sh` / `fetch_kernel.ps1`：一键克隆脚本。
