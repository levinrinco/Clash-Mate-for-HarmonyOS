#Requires -Version 7.0
# tools\_common.ps1 —— 工作区脚本公用函数。其它脚本用 . "$PSScriptRoot\_common.ps1" 引入。

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Get-WorkspaceRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-WorkspaceConfig {
    $path = Join-Path (Get-WorkspaceRoot) 'workspace.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "找不到 workspace.json：$path"
    }
    return Read-Json5File -Path $path
}

# 宽容解析 JSON5：去注释、去尾逗号。够用于本工作区的配置文件自检。
function ConvertFrom-Json5 {
    param([Parameter(Mandatory)][string]$Text)

    $t = [regex]::Replace($Text, '(?s)/\*.*?\*/', '')
    $t = [regex]::Replace($t, '(?m)(?<!:)//.*$', '')
    $t = [regex]::Replace($t, ',(?=\s*[}\]])', '')
    return $t | ConvertFrom-Json
}

function Read-Json5File {
    param([Parameter(Mandatory)][string]$Path)
    return ConvertFrom-Json5 -Text (Get-Content -Raw -LiteralPath $Path -Encoding utf8)
}

# ---------- 输出 ----------
function Write-Banner {
    param([string]$Title)
    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ('  ' + ('─' * [Math]::Max(20, $Title.Length + 8))) -ForegroundColor DarkGray
}

# 终端里中文占两列，PadRight 按字符数算会歪，这里按显示宽度补空格
function Get-TextWidth {
    param([string]$Text)
    $width = 0
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        if (($code -ge 0x1100 -and $code -le 0x115F) -or
            ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
            ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
            ($code -ge 0xF900 -and $code -le 0xFAFF) -or
            ($code -ge 0xFE30 -and $code -le 0xFE6F) -or
            ($code -ge 0xFF00 -and $code -le 0xFF60) -or
            ($code -ge 0xFFE0 -and $code -le 0xFFE6)) {
            $width += 2
        } else {
            $width += 1
        }
    }
    return $width
}

function Format-Label {
    param([string]$Label, [int]$Width = 18)
    $pad = $Width - (Get-TextWidth $Label)
    if ($pad -lt 0) { $pad = 0 }
    return $Label + (' ' * $pad)
}

function Write-Item {
    param(
        [ValidateSet('ok', 'warn', 'bad', 'info')][string]$Status,
        [string]$Label,
        [string]$Detail = '',
        [string]$Hint = ''
    )
    $icon = switch ($Status) {
        'ok' { '✔' }
        'warn' { '!' }
        'bad' { '✖' }
        'info' { '·' }
    }
    $color = switch ($Status) {
        'ok' { 'Green' }
        'warn' { 'Yellow' }
        'bad' { 'Red' }
        'info' { 'DarkGray' }
    }
    Write-Host ("  [{0}] {1} {2}" -f $icon, (Format-Label $Label), $Detail) -ForegroundColor $color
    if ($Hint) {
        Write-Host ("       ↳ {0}" -f $Hint) -ForegroundColor DarkGray
    }
}

function Write-Tip {
    param([string]$Text)
    Write-Host "  $Text" -ForegroundColor DarkGray
}

function Write-Step {
    param([string]$Text)
    Write-Host ''
    Write-Host "  » $Text" -ForegroundColor Cyan
}

# ---------- 环境探测 ----------
function Find-DevEcoHome {
    $cfg = Get-WorkspaceConfig
    $candidates = @(
        $cfg.devEcoHome
        $env:DEVECO_STUDIO_HOME
        'C:\Program Files\Huawei\DevEco Studio'
        'C:\Program Files (x86)\Huawei\DevEco Studio'
        'D:\Huawei\DevEco Studio'
        'D:\DevEco Studio'
        'D:\Program Files\Huawei\DevEco Studio'
        (Join-Path $env:LOCALAPPDATA 'Huawei\DevEco Studio')
    )
    foreach ($c in $candidates) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if (-not (Test-Path -LiteralPath $c)) { continue }
        if ((Test-Path (Join-Path $c 'bin\devecostudio64.exe')) -or
            (Test-Path (Join-Path $c 'bin\devecostudio.exe'))) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }
    return $null
}

function Test-SdkHome {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    foreach ($child in @('ets', 'toolchains', 'default', 'harmonyos', 'openharmony', 'hmscore')) {
        if (Test-Path (Join-Path $Path $child)) { return $true }
    }
    # SDK 根目录下通常还有一层版本目录
    $subs = Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue
    foreach ($s in $subs) {
        foreach ($child in @('ets', 'toolchains', 'openharmony', 'harmonyos')) {
            if (Test-Path (Join-Path $s.FullName $child)) { return $true }
        }
    }
    return $false
}

function Find-SdkHome {
    $cfg = Get-WorkspaceConfig
    $devEco = Find-DevEcoHome
    $candidates = @(
        $cfg.sdkHome
        $env:DEVECO_SDK_HOME
        $env:HOS_SDK_HOME
        (Join-Path $env:LOCALAPPDATA 'Huawei\Sdk')
        (Join-Path $env:LOCALAPPDATA 'OpenHarmony\Sdk')
    )
    if ($devEco) { $candidates += (Join-Path $devEco 'sdk') }
    foreach ($c in $candidates) {
        if (Test-SdkHome -Path $c) { return (Resolve-Path -LiteralPath $c).Path }
    }
    return $null
}

function Find-Executable {
    param(
        [string[]]$Candidates,
        [string]$CommandName
    )
    foreach ($c in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
    }
    if ($CommandName) {
        $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Find-Hvigorw {
    $devEco = Find-DevEcoHome
    $candidates = @()
    if ($devEco) {
        $candidates += (Join-Path $devEco 'tools\hvigor\bin\hvigorw.bat')
        $candidates += (Join-Path $devEco 'tools\hvigor\bin\hvigorw')
    }
    if ($env:HOS_SDK_HOME) {
        $candidates += (Join-Path $env:HOS_SDK_HOME 'hvigor\bin\hvigorw.bat')
    }
    return Find-Executable -Candidates $candidates -CommandName 'hvigorw'
}

function Find-Ohpm {
    $devEco = Find-DevEcoHome
    $candidates = @()
    if ($devEco) {
        $candidates += (Join-Path $devEco 'tools\ohpm\bin\ohpm.bat')
        $candidates += (Join-Path $devEco 'tools\ohpm\bin\ohpm')
    }
    return Find-Executable -Candidates $candidates -CommandName 'ohpm'
}

function Find-Hdc {
    $sdk = Find-SdkHome
    if ($sdk) {
        $found = Get-ChildItem -LiteralPath $sdk -Filter 'hdc.exe' -Recurse -Depth 4 -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    $devEco = Find-DevEcoHome
    $candidates = @()
    if ($devEco) {
        $candidates += (Join-Path $devEco 'tools\hdc\hdc.exe')
        $candidates += (Join-Path $devEco 'sdk\toolchains\hdc.exe')
    }
    return Find-Executable -Candidates $candidates -CommandName 'hdc'
}

function Find-Node {
    $devEco = Find-DevEcoHome
    $candidates = @()
    if ($devEco) {
        $candidates += (Join-Path $devEco 'tools\node\node.exe')
    }
    return Find-Executable -Candidates $candidates -CommandName 'node'
}

function Find-Java {
    $devEco = Find-DevEcoHome
    $candidates = @()
    if ($devEco) {
        $candidates += (Join-Path $devEco 'jbr\bin\java.exe')
    }
    if ($env:JAVA_HOME) {
        $candidates += (Join-Path $env:JAVA_HOME 'bin\java.exe')
    }
    return Find-Executable -Candidates $candidates -CommandName 'java'
}

# ---------- 工程 ----------
function Get-AppList {
    $appsDir = Join-Path (Get-WorkspaceRoot) 'apps'
    if (-not (Test-Path -LiteralPath $appsDir)) { return @() }
    return Get-ChildItem -LiteralPath $appsDir -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'build-profile.json5') } |
        Select-Object -ExpandProperty Name
}

function Resolve-AppDir {
    param([Parameter(Mandatory)][string]$Name)
    $appsDir = Join-Path (Get-WorkspaceRoot) 'apps'
    $dir = Join-Path $appsDir $Name
    if (-not (Test-Path -LiteralPath $dir)) {
        $available = (Get-AppList) -join ', '
        if (-not $available) { $available = '（暂无）' }
        throw "apps 下没有工程「$Name」。现有：$available"
    }
    return (Resolve-Path -LiteralPath $dir).Path
}

function Get-AppBundleName {
    param([Parameter(Mandatory)][string]$AppDir)
    $appJson = Join-Path $AppDir 'AppScope\app.json5'
    if (-not (Test-Path -LiteralPath $appJson)) { return $null }
    return (Read-Json5File -Path $appJson).app.bundleName
}
