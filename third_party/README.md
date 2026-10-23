# third_party

本目录只放版本锁定和说明，不提交上游源码。

```powershell
git clone https://github.com/MetaCubeX/mihomo.git third_party/mihomo
git -C third_party/mihomo checkout 3f27ef39f8c96bbfbc8b0b9bb10f5c9ef60149d8
```

`native/bridge/go.mod` 里有一行：

```text
replace github.com/metacubex/mihomo => ../../third_party/mihomo
```

所以 `third_party/mihomo` 必须在仓库根目录下，路径不能改。

- mihomo：GPL-3.0
- gVisor：Apache-2.0（Go 模块，见 `go.sum`）
- Clash Meta for Android：GPL-3.0，仅作 UI/字符串/图标参考，不参与鸿蒙构建

完整列表见根目录 `NOTICE`。
