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
        } elseif ((Get-FileHash $target).Hash -eq (Get-FileHash $source).Hash) {
            # 既に同一内容のコピーが置かれている → 何もしない。
            # (再実行で本物のバックアップをコピーで上書きしてしまうのを防ぐ)
            Write-Ok "最新: $target (コピー済み)"
            return
        } else {
            $bak = "$target.backup"
            if (Test-Path $bak) { Remove-Item $bak -Force }
            Move-Item $target $bak -Force
            Write-Warn2 "既存を $bak に退避しました"
        }
    }
    # symlink を試し、ダメならコピーにフォールバックする。
    # 開発者モードが ON でも「リンク先が \\wsl.localhost\... の UNC パス」だと
    # 管理者権限が要求されて失敗するため、Test-CanSymlink だけに頼らず実際に
    # 作ってみて例外を握る(ここで throw させると $ErrorActionPreference=Stop で
    # bootstrap 全体が中断し、後段の AHK 登録まで巻き添えで止まる)。
    if (Test-CanSymlink) {
        try {
            New-Item -ItemType SymbolicLink -Path $target -Target $source -ErrorAction Stop | Out-Null
            Write-Ok "リンク: $target -> $source"
            return
        } catch {
            Write-Warn2 "シンボリックリンク不可(WSL の UNC パス等)。コピー配置にフォールバック。"
        }
    }
    Copy-Item $source $target -Force
    Write-Ok "コピー: $target"
}

# --- 1. WezTerm 設定 --------------------------------------------------------
Write-Host "==> WezTerm 設定を配置" -ForegroundColor Cyan
Install-Link (Join-Path $here 'wezterm.lua') (Join-Path $env:USERPROFILE '.wezterm.lua')

if (-not (Get-Command wezterm-gui.exe -ErrorAction SilentlyContinue) `
    -and -not (Test-Path "$env:ProgramFiles\WezTerm\wezterm-gui.exe")) {
    Write-Warn2 "WezTerm が見つかりません。'winget install wez.wezterm' で導入してください。"
}

# --- 2. AutoHotkey スクリプト ----------------------------------------------
Write-Host "==> AutoHotkey スクリプトを登録" -ForegroundColor Cyan
$ahkExe = @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe",
    "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

# 1本の .ahk を「ログイン時自動起動に登録 + 今すぐ起動」する。冪等。
function Register-Ahk($ahkExe, $scriptName, $lnkName, $description) {
    $ahkScript = Join-Path $here $scriptName
    $lnkPath = Join-Path ([Environment]::GetFolderPath('Startup')) $lnkName
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut($lnkPath)
    $lnk.TargetPath       = $ahkExe
    $lnk.Arguments        = '"' + $ahkScript + '"'
    $lnk.WorkingDirectory = $here
    $lnk.Description       = $description
    $lnk.Save()
    Write-Ok "自動起動を登録: $lnkPath"
    Start-Process -FilePath $ahkExe -ArgumentList ('"' + $ahkScript + '"')
    Write-Ok "$scriptName を起動しました"
}

if (-not $ahkExe) {
    Write-Warn2 "AutoHotkey v2 が見つかりません。'winget install AutoHotkey.AutoHotkey' で導入してください。"
} else {
    Write-Ok "AutoHotkey: $ahkExe"
    Register-Ahk $ahkExe 'caps-toggle.ahk' 'caps-toggle.lnk' 'Caps Lock 2度押しでターミナルをトグル'
    Register-Ahk $ahkExe 'ime-shift.ahk'   'ime-shift.lnk'   '左Shift=英数 / 右Shift=かな (Mac風IME切替)'
}

Write-Host ""
Write-Host "完了。Caps Lock 2回 → WezTerm 表示/非表示、左Shift=英数 / 右Shift=かな。" -ForegroundColor Cyan
