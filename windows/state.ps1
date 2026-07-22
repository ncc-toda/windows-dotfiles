# ---------------------------------------------------------------------------
# state.ps1 — 「このセットアップが学生のマシンに何をしたか」の台帳
#
# bootstrap.ps1 / install.ps1 が dot-source して使い、uninstall.ps1 がこれを
# 逆再生して原状復帰する。配布物なので「入れた物を全部消せる」ことが前提であり、
# 消す側が推測でファイルを消しに行かなくて済むよう、書いた側が記録する。
#
# 置き場所: %LOCALAPPDATA%\ncc-dotfiles\
#     manifest.json       触った物の記録 (下記 entry の配列)
#     backup\<日時>\      退避した既存ファイルの実体
#
# entry の type:
#   file    … 配置したファイル (path) と、退避した既存ファイル (backup)
#   font    … 導入したフォント (path) とレジストリ登録 (regKey/regName)
#   startup … スタートアップに置いたショートカット (path)
#   winget  … winget で導入したパッケージ (id)
#   wsl     … 作成した WSL ディストロ (distro)
#   wsl-default … 既定の WSL ディストロを変えた記録 (distro/previous)
#   shell   … chsh でログインシェルを変えた記録 (distro/user/previous)
#
# 冪等性: 同じ物を二度記録しない (type + 識別子で突き合わせる)。よって
# bootstrap を何度回しても台帳は膨らまない。
# ---------------------------------------------------------------------------

$script:NccStateDir  = Join-Path $env:LOCALAPPDATA 'ncc-dotfiles'
$script:NccManifest  = Join-Path $script:NccStateDir 'manifest.json'
$script:NccBackupDir = $null   # 実際に退避するまで作らない (空フォルダを残さない)

function Get-NccManifest {
    if (Test-Path $script:NccManifest) {
        try {
            $m = Get-Content $script:NccManifest -Raw -Encoding UTF8 | ConvertFrom-Json
            # ConvertFrom-Json は要素1個の配列をスカラーに潰すので配列へ戻す。
            $entries = @($m.entries)
            return [pscustomobject]@{ version = $m.version; createdAt = $m.createdAt; entries = $entries }
        } catch {
            # 壊れた台帳で全体を止めない。退避してから作り直す。
            Move-Item $script:NccManifest "$script:NccManifest.broken" -Force -ErrorAction SilentlyContinue
        }
    }
    return [pscustomobject]@{
        version   = 1
        createdAt = (Get-Date -Format 'o')
        entries   = @()
    }
}

function Save-NccManifest($manifest) {
    if (-not (Test-Path $script:NccStateDir)) {
        New-Item -ItemType Directory -Path $script:NccStateDir -Force | Out-Null
    }
    $manifest.entries = @($manifest.entries)
    $manifest | ConvertTo-Json -Depth 6 | Set-Content $script:NccManifest -Encoding UTF8
}

# entry を1件記録する。同一エントリがあれば何もしない (冪等)。
# $key は「同一性を判断するプロパティ名」の配列。
function Add-NccEntry($manifest, [hashtable]$entry, [string[]]$key) {
    $new = [pscustomobject]$entry
    foreach ($e in $manifest.entries) {
        if ($e.type -ne $new.type) { continue }
        $same = $true
        foreach ($k in $key) {
            if ($e.$k -ne $new.$k) { $same = $false; break }
        }
        if ($same) { return $manifest }   # 記録済み
    }
    $manifest.entries = @($manifest.entries) + $new
    return $manifest
}

# 退避先フォルダを (初回だけ) 作って返す。日時付きなので、過去のバックアップを
# 上書きして壊すことがない。
function Get-NccBackupDir {
    if (-not $script:NccBackupDir) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $script:NccBackupDir = Join-Path $script:NccStateDir "backup\$stamp"
    }
    if (-not (Test-Path $script:NccBackupDir)) {
        New-Item -ItemType Directory -Path $script:NccBackupDir -Force | Out-Null
    }
    return $script:NccBackupDir
}
