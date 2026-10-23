# Clash Mate for HarmonyOS

[![Release](https://img.shields.io/github/v/release/levinrinco/Clash-Mate-for-HarmonyOS?label=release)](https://github.com/levinrinco/Clash-Mate-for-HarmonyOS/releases/latest)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

基于 [mihomo](https://github.com/MetaCubeX/mihomo) 内核，用 ArkTS + VpnExtensionAbility 实现的鸿蒙原生代理客户端。

> **非官方项目**：与 MetaCubeX、Clash Meta、华为均无隶属关系，未获其背书。
> 代码以 **GPL-3.0** 发布，详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。
>
> 这是独立的鸿蒙原生实现，**不是 Clash Meta for Android 的 GitHub fork**。
> 版本号跟随上游 CMFA，鸿蒙侧单独修复时用 `.Meta.N` 区分。

- 包名：`com.dafeiyu.clashmate`
- 版本：`2.11.36.Meta`
- 设备：HarmonyOS 手机 / 平板，兼容 5.0.5(17) 及以上

## 功能

- 系统级 TUN VPN（`VpnExtensionAbility`），不是本地 HTTP 代理
- 桌面卡片连接/断开，不打开 App 也能连
- 数据传输长时任务：多任务界面**一键清理**不会断连
- 系统实况窗显示本次连接的上行/下行流量
- 订阅导入、配置切换、代理模式（规则/全局/直连）
- 节点分组、节点切换、延迟测速
- DNS/网络/内核设置、日志
- 6 套浅色/深色主题，桌面卡片独立配色

## 安装

### 未签名 HAP

仓库不附带签名证书，GitHub Releases 里的 HAP 是**未签名包**，不能直接 `hdc install`。

下载地址：

- Release 页面：https://github.com/levinrinco/Clash-Mate-for-HarmonyOS/releases/latest
- 当前版本：https://github.com/levinrinco/Clash-Mate-for-HarmonyOS/releases/download/v2.11.36/clashmate-2.11.36-unsigned.hap
- 仓库内备份：[`release/clashmate-2.11.36-unsigned.hap`](release/clashmate-2.11.36-unsigned.hap)

校验：

```powershell
Get-FileHash .\clashmate-2.11.36-unsigned.hap -Algorithm SHA256
```

期望值见 [`release/SHA256SUMS.txt`](release/SHA256SUMS.txt)。

### 签名后安装

未签名包必须先用自己的证书和 profile 签名。两种方式：

**方式 A：DevEco Studio 自动签名（推荐）**

1. 用 DevEco Studio 打开 `apps/ClashMate`
2. `File → Project Structure → Project → Signing Configs`
3. 勾选自动生成签名，登录华为账号
4. 连接手机/平板，直接 Run，或 Build 出已签名 HAP

**方式 B：已有证书，用 SDK 工具签名**

用 HarmonyOS SDK 里的 `hap-sign-tool.jar`（一般在 `toolchains/lib` 下），按自己的 `app.cer`、`.p7b`、`.p12` 签名。不同 SDK 版本参数略有差异，以本机工具帮助为准。

签名完成后安装：

```powershell
hdc install .\entry-default-signed.hap
```

如果设备上已有用其他证书签名的旧版本，需要先卸载，卸载会清空 App 数据：

```powershell
hdc uninstall com.dafeiyu.clashmate
```

## 构建

### 环境

- Windows 10/11 + PowerShell 7
- DevEco Studio，HarmonyOS SDK API 22（`6.0.2(22)`）
- 重新编译内核时需要 OpenHarmony 版 Go 工具链 `go126ohos`（官方 Go 不支持 `openharmony/arm64` 的 c-shared）
- 真机安装需要自己的签名证书；仓库不包含任何证书或密码

### 1. 获取 mihomo 源码

```powershell
git clone https://github.com/MetaCubeX/mihomo.git third_party/mihomo
git -C third_party/mihomo checkout 3f27ef39f8c96bbfbc8b0b9bb10f5c9ef60149d8
```

版本锁定见 [`third_party/LOCK.json`](third_party/LOCK.json)。

### 2. 编译内核桥接层

```powershell
.\tools\build-bridge.ps1
```

脚本会调用 `go126ohos`，把 `native/bridge` 和 mihomo 编成 `apps/ClashMate/entry/libs/arm64-v8a/libmihomo.so`。

### 3. 编译 App

```powershell
.\tools\build.ps1 -App ClashMate
```

产物在 `apps/ClashMate/entry/build/default/outputs/default/`。仓库里的 `build-profile.json5` 没有签名配置，所以默认产出 `entry-default-unsigned.hap`。

## 版本与上游

- 上游参考：Clash Meta for Android `2.11.36`（commit 见 `third_party/LOCK.json`）
- 内核：mihomo `3f27ef39f8c96bbfbc8b0b9bb10f5c9ef60149d8`
- 跟进方式：Watch CMFA 的 Releases，按行为和资源差异移植；不合并 Android 代码，也不使用 GitHub fork 关系
- 版本规则：`2.11.36.Meta` 对应 CMFA `2.11.36`；鸿蒙侧修复递增为 `2.11.36.Meta.1`、`.2`，同时递增 `versionCode`

## 目录

```text
apps/ClashMate/     HarmonyOS 应用工程（ArkTS + NAPI）
native/bridge/      Go 桥接层，编译成 libmihomo.so
tools/              构建脚本
third_party/        上游版本锁定，不含上游源码
release/            未签名 HAP
```

## 已知限制

- 代理页通过 `127.0.0.1:9090` 的 REST 读内核状态，依赖订阅里的 `external-controller`
- 分组名带 `/` 时 REST 路径会被拆开，切换会失败
- 多任务界面**一键清理**不会断连；**单独上滑** Clash Mate 卡片仍会杀掉进程并断连，这是系统行为
- App 被硬杀、未走生命周期时，桌面卡片可能短暂保留旧状态；点一下卡片会自愈
- 只支持 IPv4 默认路由，IPv6 未接管

## 许可证

GPL-3.0。内核 [mihomo](https://github.com/MetaCubeX/mihomo) 与 sing/sing-tun 为 GPL-3.0，gVisor 为 Apache-2.0，详见 [NOTICE](NOTICE)。
