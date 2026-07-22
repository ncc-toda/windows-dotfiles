#Requires -Version 5.1
<#
.SYNOPSIS
    install.ps1 が加えた変更を、記録 (manifest) を逆再生して元に戻す。

.DESCRIPTION
    %LOCALAPPDATA%\ncc-dotfiles\manifest.json を読み、記録されている変更だけを
    取り消す。推測でファイルを消しに行かないので、学生が元から持っていた物を
    巻き込まない。

    既定では Nix を消さない (別用途で使っているかもしれないため)。授業専用の WSL
    ディストロは丸ごと unregister する。

    実行:
        # 展開済みの場合
        .\uninstall.ps1
        # ネットから直接
        irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/release/uninstall.ps1 | iex
#>

# irm|iex は param() を扱えない (install.ps1 と同じ理由)。引数は環境変数で受ける。
#   $env:NCC_REMOVE_NIX=1   WSL 内の Nix も消す (既定は残す)
#   $env:NCC_KEEP_DISTRO=1  授業専用ディストロを消さずに残す
#   $env:NCC_KEEP_APPS=1    winget で入れた WezTerm/AHK を消さずに残す
#   $env:NCC_YES=1          確認プロンプトを飛ばす
$RemoveNix  = [bool]$env:NCC_REMOVE_NIX
$KeepDistro = [bool]$env:NCC_KEEP_DISTRO
$KeepApps   = [bool]$env:NCC_KEEP_APPS
$Yes        = [bool]$env:NCC_YES

$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
# 配布 ref (install.ps1 と揃える)。ネットから state.ps1 を拾う際の ref。
$Ref = 'release'

function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    OK: $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    警告: $m" -ForegroundColor Yellow }

# Linux コマンド用 (UTF-8)。wsl -d X -- wslpath/bash ... の出力はそのまま UTF-8。
# 一律 UTF-16 で読むと wslpath の ASCII 出力が CJK に化けてパスが壊れる。
function Invoke-Wsl {
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        & wsl.exe @args
    } finally {
        [Console]::OutputEncoding = $prev
    }
}
# WSL 組込コマンド用 (UTF-16LE)。-l / --unregister / --terminate ...
function Invoke-WslCli {
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        & wsl.exe @args
    } finally {
        [Console]::OutputEncoding = $prev
    }
}
function ConvertTo-WslPath($distro, $winPath) {
    $fwd = $winPath -replace '\\', '/'
    ((Invoke-Wsl -d $distro -- wslpath -u "$fwd") | Select-Object -First 1).Trim()
}

# state.ps1 を読む。irm|iex で $PSScriptRoot が無い場合はネットから拾う。
$here = if ($PSScriptRoot) { $PSScriptRoot } else { $null }
$statePs1 = if ($here) { Join-Path $here 'windows\state.ps1' } else { $null }
if (-not $statePs1 -or -not (Test-Path $statePs1)) {
    $tmp = Join-Path $env:TEMP 'ncc-state.ps1'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing `
        -Uri "https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/$Ref/windows/state.ps1" `
        -OutFile $tmp
    $statePs1 = $tmp
}
# 文字列経由で読み込む (実行ポリシー Restricted のマシンでも止まらないように)。
. ([scriptblock]::Create((Get-Content -Raw $statePs1)))

if (-not (Test-Path $script:NccManifest)) {
    Warn "変更の記録 ($script:NccManifest) がありません。取り消す対象がありません。"
    return   # irm|iex では exit だとウィンドウごと閉じるため return で止める
}
$manifest = Get-NccManifest
$entries = @($manifest.entries)

# 何を戻すかを見せてから実行する。
Write-Host ""
Write-Host "  以下を元に戻します:" -ForegroundColor Cyan
$byType = $entries | Group-Object type
foreach ($g in $byType) { Write-Host ("    {0,-9} {1} 件" -f $g.Name, $g.Count) }
if (-not $RemoveNix)  { Write-Host "    (WSL 内の Nix は残します。消すには -RemoveNix)" -ForegroundColor DarkGray }
if ($KeepDistro)      { Write-Host "    (授業専用ディストロは残します)" -ForegroundColor DarkGray }
Write-Host ""
if (-not $Yes) {
    $ans = Read-Host "  実行しますか? [y/N]"
    if ($ans -ne 'y' -and $ans -ne 'Y') { Write-Host "  中止しました。"; return }
}

# --- 1. スタートアップ登録を外す (常駐 AHK を止めてから) --------------------
Say "常駐スクリプトを停止・登録解除"
foreach ($e in $entries | Where-Object { $_.type -eq 'startup' }) {
    if (Test-Path $e.path) { Remove-Item $e.path -Force; Ok "削除: $($e.path)" }
}
# 動いている AHK を止める。ime-shift / caps-toggle は AutoHotkey プロセスなので、
# 該当スクリプトを引数に持つものだけ狙って落とす (他の AHK を巻き込まない)。
Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'caps-toggle\.ahk|ime-shift\.ahk' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# --- 2. フォント: レジストリ登録を外す。ファイルは自分で入れた物だけ消す -----
Say "フォントの登録を解除"
$fontsKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
foreach ($e in $entries | Where-Object { $_.type -eq 'font' }) {
    if (Test-Path $fontsKey) {
        Remove-ItemProperty -Path $fontsKey -Name $e.regName -Force -ErrorAction SilentlyContinue
    }
    if ($e.installedByUs -and (Test-Path $e.path)) {
        Remove-Item $e.path -Force -ErrorAction SilentlyContinue
    }
}
Ok "解除しました (学生が元から持っていたフォントのファイルは残しています)"

# --- 3. 配置したファイルを消し、退避してあった元ファイルを戻す --------------
Say "配置ファイルを撤去・復元"
foreach ($e in $entries | Where-Object { $_.type -eq 'file' }) {
    if (Test-Path $e.path) { Remove-Item $e.path -Force -ErrorAction SilentlyContinue }
    if ($e.backup -and (Test-Path $e.backup)) {
        Move-Item $e.backup $e.path -Force
        Ok "復元: $($e.path)"
    }
}

# --- 4. WSL 側 -------------------------------------------------------------
# 授業専用ディストロ (createdByUs) は丸ごと消すのが一番きれい。既存ディストロに
# 入れた場合は中で teardown.sh を回して home-manager / dotfiles / (任意で Nix) を外す。
$wslEntry = $entries | Where-Object { $_.type -eq 'wsl' -and $_.createdByUs } | Select-Object -First 1
if ($wslEntry -and -not $KeepDistro) {
    Say "授業専用ディストロ '$($wslEntry.distro)' を削除"
    Invoke-WslCli --unregister $wslEntry.distro
    if ($LASTEXITCODE -eq 0) { Ok "削除しました (中身ごと消えました)" }
    else { Warn "unregister に失敗しました" }
} else {
    # 既存ディストロを対象にしていた。teardown.sh をそのディストロで回す。
    $distro = if ($wslEntry) { $wslEntry.distro } else {
        (@($entries | Where-Object { $_.type -eq 'wslconf' }) | Select-Object -First 1).distro
    }
    if (-not $distro) {
        # 記録に無い = 既存ディストロだが distro 名を残していない旧経路。既定へ。
        $distro = (@(Invoke-WslCli -l -q | ForEach-Object { $_.Trim() } | Where-Object { $_ }))[0]
    }
    if ($distro) {
        Say "ディストロ '$distro' の WSL 側を後始末"
        $teardownWin = if ($here) { Join-Path $here 'scripts\teardown.sh' } else { $null }
        if ($teardownWin -and (Test-Path $teardownWin)) {
            $teardownLin = ConvertTo-WslPath $distro $teardownWin
            $td = @('bash', $teardownLin)
            if ($RemoveNix) { $td += '--remove-nix' }
            Invoke-Wsl -d $distro -- @td
        } else {
            Warn "teardown.sh が手元に無いためスキップ (WSL 内で手動: home-manager uninstall)"
        }
    }

    # 既存ディストロの wsl.conf に足した systemd 設定を戻す。
    foreach ($e in $entries | Where-Object { $_.type -eq 'wslconf' }) {
        if ($e.backup) {
            Invoke-Wsl -d $e.distro -u root -- bash -c `
                "test -f '$($e.backup)' && mv '$($e.backup)' /etc/wsl.conf || rm -f /etc/wsl.conf"
        }
    }
}

# install.ps1 が授業用に切り替えた「既定の WSL ディストロ」を元に戻す。元ディストロが
# まだ残っている時だけ (授業専用ディストロを unregister した後は Windows が既定を
# 自動で選び直すが、記録があるなら学生が元々使っていた既定へ明示的に戻す)。
$defEntry = @($entries | Where-Object { $_.type -eq 'wsl-default' }) | Select-Object -First 1
if ($defEntry -and $defEntry.previous) {
    $present = @(Invoke-WslCli -l -q | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($present -contains $defEntry.previous) {
        Say "既定の WSL ディストロを元の '$($defEntry.previous)' に戻す"
        Invoke-WslCli --set-default $defEntry.previous | Out-Null
        if ($LASTEXITCODE -eq 0) { Ok "既定ディストロを戻しました" }
        else { Warn "既定ディストロの復元に失敗 (手動で: wsl --set-default $($defEntry.previous))" }
    } else {
        Warn "元の既定ディストロ '$($defEntry.previous)' が見つからないため復元をスキップ"
    }
}

# --- 5. winget で入れたアプリ ----------------------------------------------
if (-not $KeepApps) {
    Say "winget で導入したアプリを削除"
    foreach ($e in $entries | Where-Object { $_.type -eq 'winget' -and $_.installedByUs }) {
        Write-Host "    削除中: $($e.id) ..."
        winget uninstall --id $e.id --exact --silent 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Ok "削除: $($e.id)" }
        else { Warn "$($e.id) の削除に失敗 (手動: winget uninstall $($e.id))" }
    }
} else {
    Warn "winget アプリは残します (-KeepApps)"
}

# --- 6. 記録そのものを消す -------------------------------------------------
Say "変更の記録を削除"
if (Test-Path $script:NccStateDir) {
    Remove-Item $script:NccStateDir -Recurse -Force -ErrorAction SilentlyContinue
    Ok "削除しました: $script:NccStateDir"
}

Write-Host ""
Write-Host "  元に戻しました。" -ForegroundColor Green
if (-not $RemoveNix -and -not ($wslEntry -and -not $KeepDistro)) {
    Write-Host "  (WSL 内の Nix は残っています。消すには: uninstall.ps1 -RemoveNix)" -ForegroundColor DarkGray
}
Write-Host ""
