# Clash Mate for HarmonyOS

[![Release](https://img.shields.io/github/v/release/levinrinco/Clash-Mate-for-HarmonyOS?label=release)](https://github.com/levinrinco/Clash-Mate-for-HarmonyOS/releases/latest)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

基于 [mihomo](https://github.com/MetaCubeX/mihomo) 内核，用 ArkTS + VpnExtensionAbility 实现的鸿蒙原生代理客户端。

> **非官方项目**：与 MetaCubeX、Clash Meta、华为均无隶属关系，未获其背书。
> 代码以 **GPL-3.0** 发布，详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。
>
> 这是独立的鸿蒙原生实现，**不是 Clash Meta for Android 的 GitHub fork**。
> 版本号跟随上游 CMFA，鸿蒙侧单独修复时用 `.N` 区分。

- 包名：`com.dafeiyu.clashmate`
- 版本：`2.11.36.1`
- 设备：HarmonyOS 手机 / 平板，兼容 5.0.5(17) 及以上

## 功能

- 系统级 TUN VPN（`VpnExtensionAbility`），不是本地 HTTP 代理
- IPv4 / IPv6 双栈，IPv6 可在设置里关闭
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
- 当前版本：https://github.com/levinrinco/Clash-Mate-for-HarmonyOS/releases/download/v2.11.36.1/clashmate-2.11.36.1-unsigned.hap
- 仓库内备份：[`release/clashmate-2.11.36.1-unsigned.hap`](release/clashmate-2.11.36.1-unsigned.hap)

校验：

```powershell
Get-FileHash .\clashmate-2.11.36.1-unsigned.hap -Algorithm SHA256
```

期望值见 [`release/SHA256SUMS.txt`](release/SHA256SUMS.txt)。

### 签名方法

这个项目只做侧载/内测分发，**不通过 AppGallery 上架**。未签名 HAP 不能直接安装，必须用华为签发的证书和 Profile 签名。

> 零售 HarmonyOS 手机不信任 OpenHarmony 自签证书。自己用 openssl 生成的自签证书只能用于 OpenHarmony 设备或已预置根证书的环境；普通鸿蒙手机需要 DevEco 自动签名，或 AGC 的调试/内部测试 Profile。

#### 方法 A：DevEco Studio 自动签名（推荐）

1. 用 DevEco Studio 打开 `apps/ClashMate`
2. `File → Project Structure → Project → Signing Configs`
3. 勾选自动生成签名，登录华为账号
4. 连接手机/平板，直接 Run，或 Build 出已签名 HAP

DevEco 会自动处理调试证书、带设备 UDID 的 Profile 和签名，最省事。

#### 方法 B：hap-sign-tool.jar 命令行重签

适合已有 `.p12` / `.cer` / `.p7b`，或者要在 CI 里签名。工具在 SDK 的 `toolchains/lib` 下：

```powershell
java -jar "C:\path\to\hap-sign-tool.jar" sign-app -mode localSign -keyAlias "<别名>" -signAlg SHA256withECDSA -appCertFile "<app.cer>" -profileFile "<profile.p7b>" -inFile "clashmate-2.11.36.1-unsigned.hap" -keystoreFile "<app.p12>" -outFile "clashmate-signed.hap" -keyPwd "<key密码>" -keystorePwd "<store密码>" -signCode "1"
```

- `-appCertFile` 是应用签名证书链（终端证书 → 中间 CA → 根证书）
- `-profileFile` 是**已签名**的 `.p7b`，不是未签名的 profile JSON
- `-signCode 1` 对 HAP 开启代码签名
- 密码填实际密码，不是 `build-profile.json5` 里的加密串
- 需要 JDK 8+

签名后安装：

```powershell
hdc install .\clashmate-signed.hap
```

如果设备上已有用其他证书签名的旧版本，需要先卸载，卸载会清空 App 数据：

```powershell
hdc uninstall com.dafeiyu.clashmate
```

官方工具源码和参数说明：https://github.com/openharmony/developtools_hapsigner

注意：`hap-sign-tool.jar` 只负责“签”，不能凭空签发华为信任的 Profile；Profile 仍需来自 DevEco 自动签名或 AGC。

#### 方法 C：GitHub 上的第三方工具

这些工具能减少手工步骤，但都属于第三方，使用前自己看源码/Release，不要把正式证书或主华为账号交给不可信工具。

**1. hpack**（Python，Apache-2.0）

适合内测打包、签名、上传和安装，使用你自己的 `.cer`、内部测试 `.p7b`、`.p12`。

```powershell
pip install harmony-hpack
hpack init
# 编辑 hpack/config.py，把三个证书文件放进 hpack/sign/
hpack p
hpack i
```

需要 AGC 的**内部测试 Profile**（包含设备 UDID），并确保 `hvigorw`、`hdc`、JDK 17+、Python 3.10+ 可用。仓库：https://github.com/iHongRen/hpack

**2. 鸿蒙安装助手 / hap-installer**（Windows GUI）

双击运行，连接设备后登录华为账号，把 HAP 拖进去，点“签名并安装”。它会自动创建调试 Profile，内置的是公开调试签名材料（来自 `likuai2010/auto-installer`），不需要自己准备证书。

仓库：https://github.com/amw1933/hap-installer

注意：

- 它会要求登录华为账号，并接触调试签名材料
- 内置的是**公共调试身份**，不是你的私有证书，不能用于正式发布
- 建议用测试账号，不要在不可信环境里登录主账号

**3. 小白调试助手 / auto-installer**

多平台 HAP 安装/调试工具，支持自定义证书；上面的公开调试材料就来自这个项目。

仓库：https://github.com/likuai2010/auto-installer

#### 签名会过期

手机端**不会自动续期**签名。证书/Profile 到期前要在 DevEco 或 AGC 重新签发，再重新构建、安装。

- 用同一个 `.p12` 密钥重签：`hdc install -r` 可以覆盖安装，数据保留
- 自动签名重新生成了新密钥：签名变了，只能先卸载再装，数据会丢
- 证书/Profile 过期后，安装/更新可能被系统拒绝；不要等到过期再处理

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
- 版本规则：`2.11.36.1` 对应 CMFA `2.11.36`；鸿蒙侧修复递增为 `.2`、`.3`，同时递增 `versionCode`

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
- IPv4 / IPv6 双栈；IPv6 需要运营商网络和上游代理支持，可在 `设置 → 网络 → 允许 IPv6` 关闭
- 个别 IPv6 目标可能因上游节点或规则不通，以实际目标为准

## 许可证

GPL-3.0。内核 [mihomo](https://github.com/MetaCubeX/mihomo) 与 sing/sing-tun 为 GPL-3.0，gVisor 为 Apache-2.0，详见 [NOTICE](NOTICE)。
