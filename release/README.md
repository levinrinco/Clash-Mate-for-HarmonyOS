# Clash Mate for HarmonyOS · 未签名 HAP

- 文件：`clashmate-2.11.36-unsigned.hap`
- SHA256：见 `SHA256SUMS.txt`
- 设备：HarmonyOS 手机 / 平板，5.0.5(17) 及以上

## 特性

- 系统级 TUN VPN（`VpnExtensionAbility`），基于 mihomo
- 桌面卡片连接/断开，不打开 App 也能连
- 数据传输长时任务，一键清理后台不断连
- 实况窗显示本次连接流量
- 订阅、配置、规则/全局/直连、节点测速、主题

## 安装

这个包由本仓库源码构建，**未签名**，不能直接 `hdc install`。

1. 用 DevEco Studio 打开 `apps/ClashMate`
2. `File → Project Structure → Project → Signing Configs`
3. 勾选自动生成签名并登录华为账号
4. 连接设备后 Run，或 Build 出已签名 HAP
5. 安装：

```powershell
hdc install .\entry-default-signed.hap
```

已有证书也可以用 SDK 的 `hap-sign-tool.jar` 自行签名后再安装。设备上有不同证书签名的旧版本时，需要先卸载（会清数据）：

```powershell
hdc uninstall com.dafeiyu.clashmate
```

- 许可证：GPL-3.0，见 `LICENSE`
- 第三方组件：见 `NOTICE`
- 完整说明：见仓库根目录 `README.md`
- 内核源码：mihomo `3f27ef39f8c96bbfbc8b0b9bb10f5c9ef60149d8`，见 `third_party/LOCK.json`
