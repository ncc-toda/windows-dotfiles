#Requires -Version 5.1
<#
.SYNOPSIS
    WezTerm 設定の配置 + フォント導入 + Caps Lock 2度押しトグルのセットアップ。

.DESCRIPTION
      1. windows/wezterm.lua を %USERPROFILE%\.wezterm.lua にリンク
      2. Fira Code Nerd Font + Symbols Nerd Font をユーザー領域に導入
      3. caps-toggle.ahk / ime-shift.ahk をログイン時に自動起動する登録 + 即起動

    冪等(何度実行してもよい)。シンボリックリンク作成には「開発者モード」または
    管理者権限が必要。どちらも無い場合は自動でコピー方式にフォールバックする。

    触った物はすべて %LOCALAPPDATA%\ncc-dotfiles\manifest.json に記録し、既存
    ファイルは同フォルダの backup\<日時>\ へ退避する。uninstall.ps1 がそれを
    逆再生して原状復帰する (windows/state.ps1 参照)。

.EXAMPLE
    # WSL のシェルから:
    /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -ExecutionPolicy Bypass \
        -File "$(wslpath -w ~/dotfiles/windows/bootstrap.ps1)"
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

. (Join-Path $here 'state.ps1')
$manifest = Get-NccManifest

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
    $backupPath = $null
    if (Test-Path $target) {
        $item = Get-Item $target -Force
        if ($item.LinkType -eq 'SymbolicLink') {
            Remove-Item $target -Force
        } elseif ((Get-FileHash $target).Hash -eq (Get-FileHash $source).Hash) {
            # 既に同一内容のコピーが置かれている → 置き直さない。
            # (再実行で本物のバックアップをコピーで上書きしてしまうのを防ぐ)
            # ただし台帳には載せる。載せないと、台帳を作り直した後の uninstall が
            # 「自分が置いたファイル」を認識できず、置き去りにしてしまう。
            Write-Ok "最新: $target (コピー済み)"
            $script:manifest = Add-NccEntry $script:manifest @{
                type = 'file'; path = $target; mode = 'copy'; backup = $null
            } @('path')
            return
        } else {
            # 学生が元から持っていたファイル。日時付きフォルダへ退避して台帳に残す。
            # (以前は "$target.backup" へ置いて既存の .backup を消していたため、
            #  2 回目の実行で「本物の元ファイル」が失われていた)
            $backupPath = Join-Path (Get-NccBackupDir) (Split-Path $target -Leaf)
            Move-Item $target $backupPath -Force
            Write-Warn2 "既存を退避しました: $backupPath"
        }
    }
    # symlink を試し、ダメならコピーにフォールバックする。
    # 開発者モードが ON でも「リンク先が \\wsl.localhost\... の UNC パス」だと
    # 管理者権限が要求されて失敗するため、Test-CanSymlink だけに頼らず実際に
    # 作ってみて例外を握る(ここで throw させると $ErrorActionPreference=Stop で
    # bootstrap 全体が中断し、後段の AHK 登録まで巻き添えで止まる)。
    $mode = 'copy'
    if (Test-CanSymlink) {
        try {
            New-Item -ItemType SymbolicLink -Path $target -Target $source -ErrorAction Stop | Out-Null
            Write-Ok "リンク: $target -> $source"
            $mode = 'symlink'
        } catch {
            Write-Warn2 "シンボリックリンク不可(WSL の UNC パス等)。コピー配置にフォールバック。"
        }
    }
    if ($mode -eq 'copy') {
        Copy-Item $source $target -Force
        Write-Ok "コピー: $target"
    }
    $script:manifest = Add-NccEntry $script:manifest @{
        type = 'file'; path = $target; mode = $mode; backup = $backupPath
    } @('path')
}

# --- 1. WezTerm 設定 --------------------------------------------------------
Write-Host "==> WezTerm 設定を配置" -ForegroundColor Cyan
Install-Link (Join-Path $here 'wezterm.lua') (Join-Path $env:USERPROFILE '.wezterm.lua')

if (-not (Get-Command wezterm-gui.exe -ErrorAction SilentlyContinue) `
    -and -not (Test-Path "$env:ProgramFiles\WezTerm\wezterm-gui.exe")) {
    Write-Warn2 "WezTerm が見つかりません。'winget install wez.wezterm' で導入してください。"
}

# --- 2. フォント (Fira Code Nerd Font + Symbols Nerd Font) ------------------
# WezTerm の本文フォント (terminal-environment.md §3)。Nerd Fonts の最新リリース
# から ZIP を取得し、ユーザー領域 (管理者不要) にインストールする。既に導入済み
# ならスキップ。ネットワーク不通等で失敗しても警告のみで bootstrap は止めない。
Write-Host "==> フォントを導入" -ForegroundColor Cyan

# GDI の AddFontResourceW + WM_FONTCHANGE ブロードキャスト用の P/Invoke。
# ファイルのコピーとレジストリ登録"だけ"では DirectWrite (WezTerm が使う) が
# 再ログインまで新規フォントを認識しない。この 2 つを呼んで初めて、実行中の
# セッションでも即座に反映される。
if (-not ('Native.FontApi' -as [type])) {
    Add-Type -Namespace Native -Name FontApi -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("gdi32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int AddFontResourceW(string lpFileName);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.IntPtr wParam, System.IntPtr lParam, uint fuFlags, uint uTimeout, out System.IntPtr lpdwResult);
'@
}

function Broadcast-FontChange {
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_FONTCHANGE  = 0x001D
    $SMTO_ABORTIFHUNG = 0x0002
    $res = [IntPtr]::Zero
    [void][Native.FontApi]::SendMessageTimeout(
        $HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero,
        $SMTO_ABORTIFHUNG, 1000, [ref]$res)
}

# ユーザー領域フォントを登録するキーは "Windows NT" 配下。"Windows" 配下 (旧版が
# 使っていた) に書いても Windows は読まないので、ログオンし直しても認識されない。
$script:UserFontsKey   = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$script:LegacyFontsKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Fonts'

function Register-UserFont($path, [bool]$installedByUs) {
    if (-not (Test-Path $script:UserFontsKey)) {
        New-Item -Path $script:UserFontsKey -Force | Out-Null
    }
    $regName = "$([IO.Path]::GetFileNameWithoutExtension($path)) (TrueType)"
    New-ItemProperty -Path $script:UserFontsKey -Name $regName -Value $path `
        -PropertyType String -Force | Out-Null
    # 実行中セッションでも即使えるように GDI へ登録する。
    [void][Native.FontApi]::AddFontResourceW($path)
    # 旧版が誤ったキーに残したゴミを掃除する。
    if (Test-Path $script:LegacyFontsKey) {
        Remove-ItemProperty -Path $script:LegacyFontsKey -Name $regName `
            -Force -ErrorAction SilentlyContinue
    }
    # installedByUs=false は「学生が元から入れていたフォント」。uninstall では
    # レジストリ登録だけ外し、ファイル本体は消さない (人の物を消さない)。
    $script:manifest = Add-NccEntry $script:manifest @{
        type = 'font'; path = $path; regName = $regName; installedByUs = $installedByUs
    } @('path')
}

function Install-NerdFont($zipName, $probeFontFile) {
    $userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    if (Test-Path (Join-Path $userFonts $probeFontFile)) {
        # ファイルはある。ただし登録は毎回やり直す: 旧版は誤ったレジストリキーに
        # 書いていたので、ファイルが揃っていても Windows からは見えないことがある。
        # 既にファイルがある = 我々が前回入れたか、学生が元から持っていたか区別が
        # つかないため、台帳に既存記録があればその installedByUs を引き継ぐ。
        $n = 0
        Get-ChildItem -Path $userFonts -Filter '*.ttf' |
            Where-Object { $_.BaseName -like ([IO.Path]::GetFileNameWithoutExtension($probeFontFile) -replace '-Regular$', '*') } |
            ForEach-Object {
                # Where-Object の中では $_ が台帳エントリに変わるので、外側の
                # ファイルパスは先に別変数へ退避しておく。
                $fontPath = $_.FullName
                $known = @($script:manifest.entries) |
                    Where-Object { $_.type -eq 'font' -and $_.path -eq $fontPath } |
                    Select-Object -First 1
                Register-UserFont $fontPath ([bool]($known -and $known.installedByUs))
                $n++
            }
        Write-Ok "既に導入済み: $zipName ($n 個を登録し直し)"
        return
    }
    $tmp = Join-Path $env:TEMP ([IO.Path]::GetFileNameWithoutExtension($zipName))
    $zipPath = "$tmp.zip"
    try {
        $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$zipName"
        Write-Host "    取得中: $url"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $tmp -Force

        if (-not (Test-Path $userFonts)) {
            New-Item -ItemType Directory -Path $userFonts -Force | Out-Null
        }
        $count = 0
        Get-ChildItem -Path $tmp -Recurse -Include '*.ttf', '*.otf' | ForEach-Object {
            $dest = Join-Path $userFonts $_.Name
            $preExisting = Test-Path $dest
            Copy-Item $_.FullName $dest -Force
            Register-UserFont $dest (-not $preExisting)
            $count++
        }
        Write-Ok "${zipName}: $count 個のフォントを導入"
    } catch {
        # 学校のネットワークが GitHub を塞いでいる等。フォントが無いと Starship の
        # アイコンが豆腐になるだけで、シェル自体は動くのでここでは止めない。
        Write-Warn2 "$zipName の導入に失敗: $($_.Exception.Message)"
        Write-Warn2 "手動導入: https://www.nerdfonts.com/font-downloads (Fira Code / Symbols Nerd Font)"
    } finally {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tmp)     { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Install-NerdFont 'FiraCode.zip'            'FiraCodeNerdFont-Regular.ttf'
Install-NerdFont 'NerdFontsSymbolsOnly.zip' 'SymbolsNerdFontMono-Regular.ttf'
# 実行中の全アプリ (WezTerm 含む) にフォント変更を通知する。
Broadcast-FontChange
Write-Ok "フォント変更を通知 (WezTerm を再起動すれば反映)"

# --- 3. AutoHotkey スクリプト ----------------------------------------------
Write-Host "==> AutoHotkey スクリプトを登録" -ForegroundColor Cyan
# v2 のみを探す。caps-toggle.ahk / ime-shift.ahk は #Requires AutoHotkey v2.0 な
# ので、v1 しか入っていないマシンで v1 に食わせると構文エラーで即死する。v1 と
# v2 は併存できるので、v1 使いの学生からは v1 を取り上げない。
$ahkExe = @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey32.exe",
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey64.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey32.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey32.exe"
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
    $script:manifest = Add-NccEntry $script:manifest @{
        type = 'startup'; path = $lnkPath; script = $ahkScript
    } @('path')
    Start-Process -FilePath $ahkExe -ArgumentList ('"' + $ahkScript + '"')
    Write-Ok "$scriptName を起動しました"
}

if (-not $ahkExe) {
    Write-Warn2 "AutoHotkey v2 が見つかりません。'winget install AutoHotkey.AutoHotkey' で導入してください。"
    Write-Warn2 "(v1 しか無い場合も同じ。v1/v2 は併存できるので v1 はそのままで構いません)"
} else {
    Write-Ok "AutoHotkey: $ahkExe"
    Register-Ahk $ahkExe 'caps-toggle.ahk' 'caps-toggle.lnk' 'Caps Lock 2度押しでターミナルをトグル'
    Register-Ahk $ahkExe 'ime-shift.ahk'   'ime-shift.lnk'   '左Shift=英数 / 右Shift=かな (Mac風IME切替)'
}

Save-NccManifest $manifest

Write-Host ""
Write-Host "完了。Caps Lock 2回 → WezTerm 表示/非表示、左Shift=英数 / 右Shift=かな。" -ForegroundColor Cyan
Write-Host "変更の記録: $script:NccManifest (元に戻すには uninstall.ps1)" -ForegroundColor DarkGray
