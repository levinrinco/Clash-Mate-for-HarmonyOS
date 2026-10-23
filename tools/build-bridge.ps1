#Requires -Version 7.0
<#
.SYNOPSIS
    编译 Go 桥接层 + mihomo，产出 apps/ClashMate/entry/libs/arm64-v8a/libmihomo.so
.DESCRIPTION
    需要 OpenHarmony 版 Go 工具链 go126ohos。官方 Go 不支持 openharmony/arm64 的 c-shared。
    默认从 %LOCALAPPDATA%\go126ohos\bin\go.exe 查找，也可用 -Go 指定。
.EXAMPLE
    .\tools\build-bridge.ps1
#>
param(
    [string]$Go
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$root = Get-WorkspaceRoot
$mihomo = Join-Path $root 'third_party\mihomo'
if (-not (Test-Path -LiteralPath $mihomo)) {
    Write-Host ''
    Write-Host '  ✖ 找不到 third_party/mihomo' -ForegroundColor Red
    Write-Tip '先拉取上游源码（版本见 third_party/LOCK.json）：'
    Write-Tip '  git clone https://github.com/MetaCubeX/mihomo.git third_party/mihomo'
    Write-Tip '  git -C third_party/mihomo checkout 3f27ef39f8c96bbfbc8b0b9bb10f5c9ef60149d8'
    exit 1
}

$sdk = Find-SdkHome
if (-not $sdk) {
    Write-Host ''
    Write-Host '  ✖ 找不到 HarmonyOS SDK，无法编译内核。' -ForegroundColor Red
    Write-Tip '在 DevEco Studio 的 SDK Manager 里安装 API 22，或设置 DEVECO_SDK_HOME'
    exit 1
}

$native = Join-Path $sdk 'default\openharmony\native'
$clang = Join-Path $native 'llvm\bin\clang.exe'
$sysroot = Join-Path $native 'sysroot'
if (-not (Test-Path -LiteralPath $clang)) {
    Write-Host "  ✖ 找不到 clang：$clang" -ForegroundColor Red
    exit 1
}

# clang 的参数不能带空格，用 junction 绕开 DevEco Studio 路径里的空格
$sdkLink = Join-Path $env:LOCALAPPDATA 'ohos-sdk'
if (-not (Test-Path -LiteralPath $sdkLink)) {
    New-Item -ItemType Junction -Path $sdkLink -Target $native | Out-Null
    Write-Tip "已创建 junction：$sdkLink -> $native"
}
$cc = Join-Path $sdkLink 'llvm\bin\clang.exe'
$ccSysroot = Join-Path $sdkLink 'sysroot'
if (-not (Test-Path -LiteralPath $cc)) {
    Write-Host "  ✖ junction 下找不到 clang：$cc" -ForegroundColor Red
    exit 1
}

if (-not $Go) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'go126ohos\bin\go.exe'),
        (Get-Command go126ohos -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
        (Get-Command go -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    )
    $Go = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
if (-not $Go) {
    Write-Host ''
    Write-Host '  ✖ 找不到 Go 工具链。' -ForegroundColor Red
    Write-Tip '需要支持 openharmony/arm64 的 go126ohos，放在 %LOCALAPPDATA%\go126ohos\bin\go.exe'
    exit 1
}

$env:CC = "$cc --target=aarch64-linux-ohos --sysroot=$ccSysroot"
$env:CGO_CFLAGS = '-D__MUSL__'
$env:CGO_ENABLED = '1'
$env:GOOS = 'openharmony'
$env:GOARCH = 'arm64'
if (-not $env:GOPATH) { $env:GOPATH = Join-Path $env:LOCALAPPDATA 'gopath' }
if (-not $env:GOCACHE) { $env:GOCACHE = Join-Path $env:LOCALAPPDATA 'gocache' }
if (-not $env:GOPROXY) { $env:GOPROXY = 'https://goproxy.cn,direct' }

$outDir = Join-Path $root 'build'
$out = Join-Path $outDir 'libmihomo-ohos-arm64.so'
$target = Join-Path $root 'apps\ClashMate\entry\libs\arm64-v8a\libmihomo.so'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null

Write-Host ''
Write-Host '  🐟 编译 libmihomo.so' -ForegroundColor Cyan
Write-Tip "Go     $Go"
Write-Tip "CC     $cc"
Write-Tip "mihomo $mihomo"
Write-Host ''

Push-Location (Join-Path $root 'native\bridge')
try {
    & $Go build -buildmode=c-shared -tags with_gvisor -trimpath -ldflags '-s -w' -o $out .
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($code -ne 0 -or -not (Test-Path -LiteralPath $out)) {
    Write-Host "  ✖ 编译失败（exit $code）" -ForegroundColor Red
    exit 1
}

Copy-Item -LiteralPath $out -Destination $target -Force
Write-Host '  ✅ 完成' -ForegroundColor Green
Write-Tip ("产物   {0}  ({1:N1} MB)" -f $target, ((Get-Item -LiteralPath $target).Length / 1MB))
Write-Host ''
