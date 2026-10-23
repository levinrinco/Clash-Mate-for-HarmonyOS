# Unsigned HAP

- `clashmate-2.11.36-unsigned.hap`
- SHA256: see `SHA256SUMS.txt`

这个包由本仓库源码构建，**未签名**，不能直接 `hdc install`。
真机安装请用 DevEco Studio 打开工程，配置自动签名后重新构建，或用 `hapsigntool` 自行签名。

- 许可证：GPL-3.0，见仓库根目录 `LICENSE`
- 第三方组件：见仓库根目录 `NOTICE`
- 源码与构建步骤：见仓库根目录 `README.md`
- 内核源码：mihomo `3f27ef39f8c96bbfbc8b0b9bb10f5c9ef60149d8`，见 `third_party/LOCK.json`
