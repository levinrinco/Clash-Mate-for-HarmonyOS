#Requires -Version 7.0
<#
.SYNOPSIS
    命令行构建 HAP。没有 DevEco Studio 的 GUI 也能出包。
.EXAMPLE
    .\tools\build.ps1
.EXAMPLE
    .\tools\build.ps1 -App HelloHarmony -Clean
.EXAMPLE
    .\tools\build.ps1 -App HelloHarmony -Task assembleApp
#>
param(
    [string]$App,
    [string]$Task = 'assembleHap',
    [string]$Product = 'default',
    [string]$Module = 'entry',
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

# 某些终端/CI 的 PATH 不含 System32，hvigor 调 es2abc 时会报 "spawn cmd.exe ENOENT"
foreach ($p in @("$env:SystemRoot\System32", $env:SystemRoot, "$env:SystemRoot\System32\Wbem")) {
    if ($p -and (Test-Path -LiteralPath $p) -and (($env:PATH -split ';') -notcontains $p)) {
        $env:PATH = "$p;$env:PATH"
    }
}

if (-not $App) {
    $all = @(Get-AppList)
    if ($all.Count -eq 1) {
        $App = $all[0]
    } elseif ($all -contains 'HelloHarmony') {
        $App = 'HelloHarmony'
    } else {
        throw "请用 -App 指定要构建的工程。现有：$($all -join ', ')"
    }
}

$appDir = Resolve-AppDir -Name $App
$hvigorw = Find-Hvigorw
if (-not $hvigorw) {
    Write-Host ''
    Write-Host '  ✖ 没找到 hvigorw，无法构建。' -ForegroundColor Red
    Write-Tip '它随 DevEco Studio 安装，一般在 <DevEco Studio>\tools\hvigor\bin\hvigorw.bat'
    Write-Tip '装好 DevEco Studio 后重新打开终端，再跑 .\tools\check-env.ps1 确认'
    exit 1
}

$sdk = Find-SdkHome
if (-not $sdk) {
    Write-Host ''
    Write-Host '  ✖ 没找到 HarmonyOS SDK，构建会失败。' -ForegroundColor Red
    Write-Tip 'DevEco Studio → SDK Manager 里下载 API 22（HarmonyOS 6.0.2）'
    exit 1
}
$env:DEVECO_SDK_HOME = $sdk

# 打包阶段 hvigor 要调 java，用 DevEco 自带的 JBR（系统没装 JDK 也能编）
$devEco = Find-DevEcoHome
if ($devEco) {
    $jbr = Join-Path $devEco 'jbr'
    if (Test-Path -LiteralPath (Join-Path $jbr 'bin\java.exe')) {
        $env:JAVA_HOME = $jbr
        $env:PATH = "$(Join-Path $jbr 'bin');$env:PATH"
    }
}

# 优先用 DevEco 自带的 Node，避免系统 Node 版本过新
$node = Find-Node
if ($node) {
    $env:PATH = "$(Split-Path $node);$env:PATH"
}

$bundle = Get-AppBundleName -AppDir $appDir
Write-Host ''
Write-Host "  🐟 构建 $App" -ForegroundColor Cyan
Write-Tip "工程   $appDir"
Write-Tip "包名   $bundle"
Write-Tip "SDK    $sdk"
Write-Tip "任务   $Task (product=$Product, module=$Module)"
Write-Host ''

Push-Location $appDir
try {
    if ($Clean) {
        Write-Step 'clean'
        & $hvigorw --mode module -p "product=$Product" -p "module=$Module@default" clean --no-daemon
    }

    Write-Step $Task
    $hvigorArgs = @(
        '--mode', 'module',
        '-p', "product=$Product",
        '-p', "module=$Module@default",
        $Task,
        '--no-daemon'
    )
    & $hvigorw @hvigorArgs
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($code -ne 0) {
    Write-Host ''
    Write-Host "  ✖ 构建失败（exit $code）" -ForegroundColor Red
    Write-Tip '常见原因：SDK 版本对不上、Node 版本太新、源码缺少 libmihomo.so'
    Write-Tip '重新编译内核： .\tools\build-bridge.ps1'
    Write-Tip '详细步骤见 README.md'
    exit $code
}

$hap = Get-ChildItem -LiteralPath (Join-Path $appDir "$Module\build") -Recurse -Filter *.hap -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

Write-Host ''
Write-Host '  ✅ 构建完成' -ForegroundColor Green
if ($hap) {
    Write-Tip ("产物   {0}  ({1:N1} MB)" -f $hap.FullName, ($hap.Length / 1MB))
    if ($hap.Name -match 'unsigned') {
        Write-Tip '这是未签名包，不能直接安装；真机安装请在 DevEco 里配置自动签名后重新构建'
    } else {
        Write-Tip "安装到设备： hdc install `"$($hap.FullName)`""
    }
}
Write-Host ''
