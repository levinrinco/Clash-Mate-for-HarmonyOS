#Requires -Version 7.0
<#
.SYNOPSIS
    工程自检：目录结构、JSON5 语法、bundleName、页面登记、资源引用是否对得上。
.EXAMPLE
    .\tools\check-app.ps1 HelloHarmony
.EXAMPLE
    .\tools\check-app.ps1            # 检查 apps 下所有工程
#>
param(
    [Parameter(Position = 0)][string]$App
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

function Get-ResourceIndex {
    param([string]$ScopeRoot)
    $index = @{ string = @(); color = @(); media = @(); profile = @() }
    $resRoot = Join-Path $ScopeRoot 'resources'
    if (-not (Test-Path -LiteralPath $resRoot)) { return $index }

    foreach ($qual in Get-ChildItem -LiteralPath $resRoot -Directory -ErrorAction SilentlyContinue) {
        $element = Join-Path $qual.FullName 'element'
        if (Test-Path -LiteralPath $element) {
            foreach ($f in Get-ChildItem -LiteralPath $element -Filter *.json -ErrorAction SilentlyContinue) {
                try { $j = Read-Json5File -Path $f.FullName } catch { continue }
                if ($j.string) { $index.string += @($j.string | ForEach-Object { $_.name }) }
                if ($j.color) { $index.color += @($j.color | ForEach-Object { $_.name }) }
            }
        }
        $media = Join-Path $qual.FullName 'media'
        if (Test-Path -LiteralPath $media) {
            $index.media += @(Get-ChildItem -LiteralPath $media -File -ErrorAction SilentlyContinue |
                    ForEach-Object { $_.BaseName })
        }
        $profile = Join-Path $qual.FullName 'profile'
        if (Test-Path -LiteralPath $profile) {
            $index.profile += @(Get-ChildItem -LiteralPath $profile -File -ErrorAction SilentlyContinue |
                    ForEach-Object { $_.BaseName })
        }
    }
    return $index
}

function Get-ResourceRefs {
    param([string]$Text)
    $refs = @()
    foreach ($m in [regex]::Matches($Text, '\$(string|color|media|profile):([A-Za-z0-9_]+)')) {
        $refs += [pscustomobject]@{ Kind = $m.Groups[1].Value; Name = $m.Groups[2].Value }
    }
    return $refs
}

function Test-App {
    param([string]$AppName)

    $errors = 0
    $warnings = 0
    $appDir = Resolve-AppDir -Name $AppName
    $bundle = '?'

    Write-Host ''
    Write-Host "  🐟 $AppName" -ForegroundColor Cyan
    Write-Host "     $appDir" -ForegroundColor DarkGray
    Write-Host ''

    # 1. 关键文件
    $required = @(
        'build-profile.json5', 'oh-package.json5', 'hvigorfile.ts',
        'hvigor\hvigor-config.json5',
        'AppScope\app.json5', 'AppScope\resources\base\element\string.json',
        'AppScope\resources\base\media\app_icon.png',
        'entry\build-profile.json5', 'entry\oh-package.json5', 'entry\hvigorfile.ts',
        'entry\src\main\module.json5',
        'entry\src\main\resources\base\profile\main_pages.json',
        'entry\src\main\resources\base\element\string.json',
        'entry\src\main\resources\base\element\color.json'
    )
    $lost = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $appDir $_)) })
    if ($lost.Count -eq 0) {
        Write-Item ok '关键文件' "齐全（$($required.Count) 个）"
    } else {
        $errors++
        Write-Item bad '关键文件' "缺 $($lost.Count) 个"
        $lost | ForEach-Object { Write-Item bad '  缺失' $_ }
    }

    # 2. JSON5 语法
    $jsonFiles = Get-ChildItem -LiteralPath $appDir -Recurse -File -Include *.json5, *.json -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(build|oh_modules|node_modules|\.hvigor)\\' }
    $badJson = @()
    foreach ($f in $jsonFiles) {
        try { $null = Read-Json5File -Path $f.FullName } catch { $badJson += $f.FullName }
    }
    if ($badJson.Count -eq 0) {
        Write-Item ok 'JSON5 语法' "通过（$($jsonFiles.Count) 个文件）"
    } else {
        $errors++
        Write-Item bad 'JSON5 语法' "$($badJson.Count) 个文件解析失败"
        $badJson | ForEach-Object { Write-Item bad '  解析失败' (Resolve-Path -Relative $_) }
    }

    if ($errors -gt 0 -and $lost.Count -gt 0) {
        return $errors
    }

    # 3. 应用信息
    try {
        $appJson = Read-Json5File -Path (Join-Path $appDir 'AppScope\app.json5')
        $bundle = $appJson.app.bundleName
        if ($bundle -match '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*){2,}$') {
            Write-Item ok 'bundleName' $bundle
        } else {
            $warnings++
            Write-Item warn 'bundleName' $bundle '建议三段式，如 com.dafeiyu.myapp'
        }
        Write-Item info '版本' "versionName $($appJson.app.versionName) / versionCode $($appJson.app.versionCode)"
    } catch {
        $errors++
        Write-Item bad 'app.json5' '读取失败'
    }

    # 4. build-profile 版本
    try {
        $profile = Read-Json5File -Path (Join-Path $appDir 'build-profile.json5')
        $product = $profile.app.products | Select-Object -First 1
        if ($product.targetSdkVersion -match '^\d+(\.\d+)*\(\d+\)$') {
            Write-Item ok 'SDK 版本' "target $($product.targetSdkVersion) / compatible $($product.compatibleSdkVersion)"
        } else {
            $warnings++
            Write-Item warn 'SDK 版本' "$($product.targetSdkVersion)" '建议写成 6.0.2(22) 这种带 API 号的格式'
        }
        $declared = @($profile.modules | ForEach-Object { $_.name })
        $onDisk = @(Get-ChildItem -LiteralPath $appDir -Directory |
                Where-Object { Test-Path (Join-Path $_.FullName 'build-profile.json5') } |
                Select-Object -ExpandProperty Name)
        $undeclared = @($onDisk | Where-Object { $_ -notin $declared })
        if ($undeclared.Count -eq 0) {
            Write-Item ok '模块登记' ($declared -join ', ')
        } else {
            $warnings++
            Write-Item warn '模块登记' "build-profile 未列出：$($undeclared -join ', ')"
        }
    } catch {
        $errors++
        Write-Item bad 'build-profile.json5' '读取失败'
    }

    # 5. 页面与 Ability
    $moduleDir = Join-Path $appDir 'entry\src\main'
    try {
        $module = (Read-Json5File -Path (Join-Path $moduleDir 'module.json5')).module
        $pagesJson = Read-Json5File -Path (Join-Path $moduleDir 'resources\base\profile\main_pages.json')
        $pageErrors = 0
        foreach ($page in @($pagesJson.src)) {
            if (-not (Test-Path -LiteralPath (Join-Path $moduleDir "ets\$page.ets"))) {
                $pageErrors++
                Write-Item bad '页面缺失' "ets\$page.ets"
            }
        }
        if ($pageErrors -eq 0) {
            Write-Item ok '页面登记' "$(@($pagesJson.src).Count) 个：$(@($pagesJson.src) -join ', ')"
        } else {
            $errors += $pageErrors
        }

        $abilityErrors = 0
        foreach ($ability in @($module.abilities)) {
            if (-not (Test-Path -LiteralPath (Join-Path $moduleDir $ability.srcEntry))) {
                $abilityErrors++
                Write-Item bad 'Ability 入口缺失' $ability.srcEntry
            }
        }
        if ($abilityErrors -eq 0) {
            Write-Item ok 'Ability' (@($module.abilities | ForEach-Object { $_.name }) -join ', ')
        } else {
            $errors += $abilityErrors
        }

        $extensions = @($module.extensionAbilities | Where-Object { $null -ne $_ })
        if ($extensions.Count -gt 0) {
            $extErrors = 0
            foreach ($ext in $extensions) {
                if (-not (Test-Path -LiteralPath (Join-Path $moduleDir $ext.srcEntry))) {
                    $extErrors++
                    Write-Item bad 'ExtensionAbility 缺失' $ext.srcEntry
                }
            }
            if ($extErrors -eq 0) {
                Write-Item ok 'ExtensionAbility' (($extensions | ForEach-Object { "$($_.name)($($_.type))" }) -join ', ')
            } else {
                $errors += $extErrors
            }
        }

        if (@($module.deviceTypes).Count -eq 0) {
            $warnings++
            Write-Item warn 'deviceTypes' '为空，至少写 phone'
        } else {
            Write-Item info 'deviceTypes' (@($module.deviceTypes) -join ', ')
        }
    } catch {
        $errors++
        Write-Item bad 'module.json5' "读取失败：$($_.Exception.Message)"
    }

    # 6. 资源引用
    $appScopeIndex = Get-ResourceIndex -ScopeRoot (Join-Path $appDir 'AppScope')
    $entryIndex = Get-ResourceIndex -ScopeRoot $moduleDir
    $merged = @{
        string  = @($appScopeIndex.string + $entryIndex.string | Select-Object -Unique)
        color   = @($appScopeIndex.color + $entryIndex.color | Select-Object -Unique)
        media   = @($appScopeIndex.media + $entryIndex.media | Select-Object -Unique)
        profile = @($appScopeIndex.profile + $entryIndex.profile | Select-Object -Unique)
    }

    $refText = ''
    foreach ($f in @('AppScope\app.json5', 'entry\src\main\module.json5')) {
        $p = Join-Path $appDir $f
        if (Test-Path -LiteralPath $p) { $refText += (Get-Content -Raw -LiteralPath $p -Encoding utf8) }
    }
    $missingRefs = @()
    foreach ($ref in (Get-ResourceRefs -Text $refText)) {
        if ($ref.Name -notin $merged[$ref.Kind]) {
            $missingRefs += "`$$($ref.Kind):$($ref.Name)"
        }
    }
    if ($missingRefs.Count -eq 0) {
        Write-Item ok '资源引用' 'app.json5 / module.json5 里引用的资源都存在'
    } else {
        $errors++
        Write-Item bad '资源引用' "缺：$($missingRefs -join ', ')"
    }

    return $errors
}

$targets = if ($App) { @($App) } else { @(Get-AppList) }
if ($targets.Count -eq 0) {
    Write-Host ''
    Write-Host '  apps 下还没有工程。' -ForegroundColor Yellow
    Write-Tip '运行 .\tools\new-app.ps1 -Name HelloHarmony 建一个'
    exit 0
}

$totalErrors = 0
foreach ($t in $targets) { $totalErrors += (Test-App -AppName $t) }

Write-Host ''
if ($totalErrors -eq 0) {
    Write-Host '  ✅ 检查通过，工程可以拿 DevEco Studio 打开或直接构建。' -ForegroundColor Green
    exit 0
} else {
    Write-Host "  ❌ 有 $totalErrors 处问题需要修。" -ForegroundColor Red
    exit 1
}
