#Requires -Version 5.1
<#
.SYNOPSIS
    WezTerm 設定の配置 + Caps Lock 2度押しトグルのセットアップ。

.DESCRIPTION
      1. windows/wezterm.lua を %USERPROFILE%\.wezterm.lua にリンク
      2. caps-toggle.ahk をログイン時に自動起動する登録 + 即起動

    冪等(何度実行してもよい)。シンボリックリンク作成には「開発者モード」または
    管理者権限が必要。どちらも無い場合は自動でコピー方式にフォールバックする。

.EXAMPLE
    # WSL のシェルから:
    /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -ExecutionPolicy Bypass \
        -File "$(wslpath -w ~/dotfiles/windows/bootstrap.ps1)"
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

function Write-Ok($m)   { Write-Host "    OK: $m"   -ForegroundColor Green }
function Write-Warn2($m){ Write-Host "    警告: $m" -ForegroundColor Yellow }

function Test-CanSymlink {
    $dev = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
        -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    return ($dev -eq 1) -or $admin
}

function Install-Link($source, $target) {
    $dir = Split-Path $target -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $target) {
        $item = Get-Item $target -Force
        if ($item.LinkType -eq 'SymbolicLink') {
            Remove-Item $target -Force
        } else {
            $bak = "$target.backup"
            if (Test-Path $bak) { Remove-Item $bak -Force }
            Move-Item $target $bak -Force
            Write-Warn2 "既存を $bak に退避しました"
        }
    }
    if (Test-CanSymlink) {
        New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
        Write-Ok "リンク: $target -> $source"
    } else {
        Copy-Item $source $target -Force
        Write-Ok "コピー: $target (開発者モード無効のためコピー配置)"
    }
}

# --- 1. WezTerm 設定 --------------------------------------------------------
Write-Host "==> WezTerm 設定を配置" -ForegroundColor Cyan
Install-Link (Join-Path $here 'wezterm.lua') (Join-Path $env:USERPROFILE '.wezterm.lua')

if (-not (Get-Command wezterm-gui.exe -ErrorAction SilentlyContinue) `
    -and -not (Test-Path "$env:ProgramFiles\WezTerm\wezterm-gui.exe")) {
    Write-Warn2 "WezTerm が見つかりません。'winget install wez.wezterm' で導入してください。"
}

# --- 2. AutoHotkey トグル ---------------------------------------------------
Write-Host "==> Caps Lock トグル(AutoHotkey)を登録" -ForegroundColor Cyan
$ahkExe = @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe",
    "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $ahkExe) {
    Write-Warn2 "AutoHotkey v2 が見つかりません。'winget install AutoHotkey.AutoHotkey' で導入してください。"
} else {
    Write-Ok "AutoHotkey: $ahkExe"
    $ahkScript = Join-Path $here 'caps-toggle.ahk'
    $lnkPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'caps-toggle.lnk'
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut($lnkPath)
    $lnk.TargetPath       = $ahkExe
    $lnk.Arguments        = '"' + $ahkScript + '"'
    $lnk.WorkingDirectory = $here
    $lnk.Description       = 'Caps Lock 2度押しでターミナルをトグル'
    $lnk.Save()
    Write-Ok "自動起動を登録: $lnkPath"
    Start-Process -FilePath $ahkExe -ArgumentList ('"' + $ahkScript + '"')
    Write-Ok "caps-toggle.ahk を起動しました"
}

Write-Host ""
Write-Host "完了。Caps Lock を素早く2回 → WezTerm が表示/非表示に切り替わります。" -ForegroundColor Cyan
