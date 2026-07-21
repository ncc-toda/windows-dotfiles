#Requires -Version 5.1
<#
.SYNOPSIS
    ターミナル環境をコマンド1つでセットアップする (学生向けの入り口)。

.DESCRIPTION
    PowerShell で:
        irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/v1.0/install.ps1 | iex

    やること:
      1. 何を変更するかを提示して同意を取る
      2. WezTerm + AutoHotkey v2 を winget で導入 (未導入のものだけ)
      3. WSL のディストロを選ぶ (授業専用を新規作成 / 既存に入れる)
      4. その中で scripts/setup.sh を実行 (Nix → home-manager)

    触った物はすべて %LOCALAPPDATA%\ncc-dotfiles\manifest.json に記録される。
    元に戻すには uninstall.ps1 を実行する。

    WSL 自体は導入済みであることを前提にしている。
#>

# 注意: このスクリプトは `irm URL | iex` で実行される。iex は内容を「スクリプト
# 本体」ではなく「文の並び」として評価するため、param() / [CmdletBinding()] を
# 先頭に置くと構文エラーになる (予期しない属性 'CmdletBinding')。よって引数は
# param() ではなく環境変数で受ける。通常は対話で使うので、どれも未設定でよい。
#   $env:NCC_DISTRO    使う/作る WSL ディストロ名を固定 (未設定なら対話選択)
#   $env:NCC_GIT_NAME / $env:NCC_GIT_EMAIL   git 身元 (未設定なら対話。任意)
#   $env:NCC_YES = 1   最初の確認プロンプトを飛ばす (教室で一斉に流す場合など)
$Distro   = $env:NCC_DISTRO
$GitName  = $env:NCC_GIT_NAME
$GitEmail = $env:NCC_GIT_EMAIL
$Yes      = [bool]$env:NCC_YES

$ErrorActionPreference = 'Stop'
# 既定が Restricted のマシンでも、このプロセスに限りスクリプトを動かせるようにする。
# (GP 強制環境では効かないが、その場合も state.ps1 は文字列経由で読むので大丈夫)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
# 配布は固定タグ (動作確認済みスナップショット) から取る。ここを 1 か所変えれば、
# Windows 側スクリプト (state.ps1 / setup.sh) の ZIP も、WSL 側 dotfiles の tar.gz
# も、setup.sh に渡す取得先も、すべて同じ ref に揃う。開発版を試すなら 'main'。
# archive/<ref>.(zip|tar.gz) の短縮形はタグ/ブランチ/コミットのいずれでも効く。
$Ref = 'v1.0'
$ZipUrl     = "https://github.com/ncc-toda/windows-dotfiles/archive/$Ref.zip"
$TarballUrl = "https://github.com/ncc-toda/windows-dotfiles/archive/$Ref.tar.gz"
$NewDistroImage = 'Ubuntu-24.04'

function Say($m)   { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "    OK: $m" -ForegroundColor Green }
function Warn($m)  { Write-Host "    警告: $m" -ForegroundColor Yellow }
function Fail($m)  { Write-Host "    エラー: $m" -ForegroundColor Red; exit 1 }

# wsl.exe の標準出力は UTF-16LE。PowerShell の既定エンコーディングのままだと
# 文字化けして -match や比較が全部外れる (ディストロ一覧が空に見える等)。
# wsl.exe を呼ぶ間だけ Unicode に切り替える。
function Invoke-Wsl {
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        & wsl.exe @args
    } finally {
        [Console]::OutputEncoding = $prev
    }
}

# Windows パスを WSL のパスに直す。
# wsl.exe へ引数を渡す途中でバックスラッシュが食われる ('C:\a\b' が 'C:ab' になる)
# ため、wslpath にはスラッシュに直してから渡す。素の文字列置換で /mnt/c/... を
# 組み立てないのは、automount root を変えている環境を壊さないため。
function ConvertTo-WslPath($winPath) {
    $fwd = $winPath -replace '\\', '/'
    $out = (Invoke-Wsl -d $Distro -- wslpath -u "$fwd") | Select-Object -First 1
    if (-not $out) { Fail "パスの変換に失敗しました: $winPath" }
    return $out.Trim()
}

# ---------------------------------------------------------------------------
# 0. 同意
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ターミナル環境セットアップ" -ForegroundColor Cyan
Write-Host "  ---------------------------------------------------------------"
Write-Host "  このマシンに対して次の変更を行います:"
Write-Host ""
Write-Host "   [Windows 側]"
Write-Host "     - WezTerm と AutoHotkey v2 を winget で導入 (未導入のものだけ)"
Write-Host "     - %USERPROFILE%\.wezterm.lua を配置 (既存があれば退避)"
Write-Host "     - Fira Code Nerd Font をユーザー領域に導入 (管理者権限は不要)"
Write-Host "     - スタートアップに常駐スクリプトを2本登録:"
Write-Host "         Caps Lock 2度押し → ターミナル表示/非表示"
Write-Host "         左Shift=英数 / 右Shift=かな (Mac 風の IME 切替)"
Write-Host ""
Write-Host "   [WSL 側]"
Write-Host "     - Nix と home-manager を導入し、シェル環境一式を構築"
Write-Host ""
Write-Host "  変更した物はすべて記録され、uninstall.ps1 で元に戻せます。" -ForegroundColor DarkGray
Write-Host "  既存のファイルは消さずに退避します。" -ForegroundColor DarkGray
Write-Host ""
if (-not $Yes) {
    $ans = Read-Host "  続けますか? [y/N]"
    if ($ans -ne 'y' -and $ans -ne 'Y') { Write-Host "  中止しました。"; exit 0 }
}

# ---------------------------------------------------------------------------
# 1. repo を取得 (state.ps1 と setup.sh がここに入っている)
# ---------------------------------------------------------------------------
# irm | iex で起動されるため $PSScriptRoot が無い。まず ZIP で一式を落とす。
# WSL 側に git や curl が無くても動くよう、取得は Windows 側で済ませる。
Say "セットアップ一式を取得"
$work = Join-Path $env:TEMP "ncc-dotfiles-setup"
if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $work -Force | Out-Null
$zip = Join-Path $work 'repo.zip'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $work -Force
} catch {
    Fail "取得に失敗しました: $($_.Exception.Message)`n    (学校のネットワークが GitHub を塞いでいる可能性があります)"
}
$src = Get-ChildItem $work -Directory | Where-Object { $_.Name -like 'windows-dotfiles-*' } | Select-Object -First 1
if (-not $src) { Fail "ZIP の中身が想定と違います" }
Ok "取得しました: $($src.FullName)"

# state.ps1 を「ファイルとして」dot-source すると、実行ポリシーが Restricted の
# マシン (学校/ラボに多い) で「スクリプトの実行が無効」になり止まる。文字列として
# 読み込みスクリプトブロック化すれば、実行ポリシー (ディスク上の .ps1 にのみ適用)
# を回避して関数を取り込める。Group Policy 強制の環境でも効く。
. ([scriptblock]::Create((Get-Content -Raw (Join-Path $src.FullName 'windows\state.ps1'))))
$manifest = Get-NccManifest

# ---------------------------------------------------------------------------
# 2. Windows 側アプリ (winget)
# ---------------------------------------------------------------------------
Say "WezTerm / AutoHotkey v2 を確認"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Fail "winget がありません。Microsoft Store で「アプリ インストーラー」を更新してください。"
}

# 「元から入っていた物」を uninstall で消してしまわないよう、導入したのが自分か
# どうかを必ず記録する。winget list の終了コードは「見つからない」で非0になる。
function Ensure-WingetPackage($id, $friendly) {
    winget list --id $id --exact --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Ok "$friendly は導入済み (このまま使います)"
        return
    }
    Write-Host "    導入中: $friendly ..."
    # UAC が出ることがある (WezTerm はマシン全体にインストールされる)。
    winget install --id $id --exact --silent `
        --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Warn "$friendly の導入に失敗しました (終了コード $LASTEXITCODE)"
        Warn "手動で: winget install $id"
        return
    }
    Ok "$friendly を導入しました"
    $script:manifest = Add-NccEntry $script:manifest @{
        type = 'winget'; id = $id; installedByUs = $true
    } @('id')
}

Ensure-WingetPackage 'wez.wezterm' 'WezTerm'
# AutoHotkey.AutoHotkey は v2 を入れる。v1 を使っている学生がいても v1/v2 は
# 併存できるので、v1 を消したり置き換えたりはしない。
Ensure-WingetPackage 'AutoHotkey.AutoHotkey' 'AutoHotkey v2'

# ---------------------------------------------------------------------------
# 3. WSL ディストロの選択
# ---------------------------------------------------------------------------
Say "WSL ディストロを選択"

# `wsl --install <image> --name <name>` は WSL 2.4.4 以降でのみ使える。
# それ未満だと「専用ディストロを作る」が黙って失敗するので先に上げておく。
$verText = (Invoke-Wsl --version) -join "`n"
$wslVer = if ($verText -match 'WSL[^\d]*(\d+)\.(\d+)\.(\d+)') {
    [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])"
} else { $null }
if (-not $wslVer -or $wslVer -lt [version]'2.4.4') {
    Write-Host "    WSL を更新しています (専用ディストロの作成に 2.4.4 以降が必要)..."
    Invoke-Wsl --update | Out-Null
}

$existing = @(Invoke-Wsl -l -q | ForEach-Object { $_.Trim() } | Where-Object { $_ })

if (-not $Distro) {
    Write-Host ""
    Write-Host "    授業用の環境をどこに作りますか?"
    Write-Host ""
    Write-Host "      [1] 授業専用の WSL を新しく作る (おすすめ)" -ForegroundColor Green
    Write-Host "          今使っている環境には一切触りません。"
    Write-Host "          要らなくなったら丸ごと消せます。ディスクを数 GB 使います。"
    Write-Host ""
    Write-Host "      [2] 今使っている WSL に入れる"
    Write-Host "          既存の設定ファイル (.bashrc 等) は退避してから置き換えます。"
    if ($existing) { Write-Host "          候補: $($existing -join ', ')" -ForegroundColor DarkGray }
    Write-Host ""
    $choice = Read-Host "    選択 [1/2] (既定: 1)"
    if (-not $choice) { $choice = '1' }

    if ($choice -eq '2') {
        if (-not $existing) { Fail "既存のディストロが見つかりません。[1] を選んでください。" }
        if ($existing.Count -eq 1) {
            $Distro = $existing[0]
        } else {
            for ($i = 0; $i -lt $existing.Count; $i++) {
                Write-Host "      [$($i+1)] $($existing[$i])"
            }
            $n = Read-Host "    どれに入れますか? [1-$($existing.Count)]"
            $idx = 0
            if (-not [int]::TryParse($n, [ref]$idx) -or $idx -lt 1 -or $idx -gt $existing.Count) {
                Fail "選択が不正です"
            }
            $Distro = $existing[$idx - 1]
        }
    } else {
        $Distro = 'ncc'
        # 同名が既にあると wsl --install は失敗する。学生が何度も流す前提なので
        # 「作り直すか / それを使うか」をここで捌く。
        while ($existing -contains $Distro) {
            Write-Host "    '$Distro' は既にあります。" -ForegroundColor Yellow
            Write-Host "      [1] それをそのまま使う (セットアップし直す)"
            Write-Host "      [2] 別の名前で新しく作る"
            $c2 = Read-Host "    選択 [1/2] (既定: 1)"
            if ($c2 -eq '2') {
                $Distro = Read-Host "    新しい名前"
                if (-not $Distro) { Fail "名前が空です" }
            } else {
                break
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 4. 必要なら専用ディストロを作る
# ---------------------------------------------------------------------------
if ($existing -notcontains $Distro) {
    Say "授業専用ディストロ '$Distro' を作成 ($NewDistroImage)"
    Write-Host "    ダウンロードに数分かかります..."
    # --no-launch: 対話的な初期ユーザー作成 (OOBE) を出さずに作る。
    # ユーザーはこの後こちらで作って /etc/wsl.conf の default に設定する。
    Invoke-Wsl --install $NewDistroImage --name $Distro --no-launch
    if ($LASTEXITCODE -ne 0) { Fail "ディストロの作成に失敗しました" }
    $script:manifest = Add-NccEntry $script:manifest @{
        type = 'wsl'; distro = $Distro; createdByUs = $true
    } @('distro')
    Ok "作成しました"

    # ユーザー名は Windows のログイン名から作るが、Linux で使える形に均す
    # (小文字化 / 使えない文字を除去 / 数字始まりを回避)。日本語名やスペース入りの
    # Windows ユーザー名でも通るようにするため。
    $lin = ($env:USERNAME.ToLower() -replace '[^a-z0-9_-]', '')
    if (-not $lin -or $lin -match '^[0-9]') { $lin = "student$lin" }
    if ($lin.Length -gt 30) { $lin = $lin.Substring(0, 30) }

    Say "ユーザー '$lin' を作成"
    Invoke-Wsl -d $Distro -u root -- useradd -m -s /bin/bash -G sudo $lin
    if ($LASTEXITCODE -ne 0) { Fail "ユーザーの作成に失敗しました" }
    # パスワードは passwd に対話で入力させる。こうすればパスワードが PowerShell の
    # 変数にもプロセス引数にも一切載らない (画面には passwd 自身の伏字が出る)。
    Write-Host "    sudo で使うパスワードを決めてください (入力は表示されません):"
    Invoke-Wsl -d $Distro -u root -- passwd $lin
    if ($LASTEXITCODE -ne 0) { Fail "パスワードの設定に失敗しました" }

    # systemd=true: Nix (Determinate installer) が nix-daemon を登録するのに要る。
    # default=<user>: 以後 `wsl -d ncc` が root ではなく学生として開く。
    #
    # stdin パイプ ($conf | Invoke-Wsl ... tee) は使わない。Invoke-Wsl 関数越しだと
    # PowerShell のパイプ入力が wsl.exe の stdin に渡らず、tee が入力待ちで固まる。
    # echo を並べて bash -c で書く (バックスラッシュを含めない = wsl.exe の引数
    # リレーが \ を食う問題も同時に避ける)。
    Invoke-Wsl -d $Distro -u root -- bash -c "{ echo '[boot]'; echo 'systemd=true'; echo; echo '[user]'; echo 'default=$lin'; } > /etc/wsl.conf"
    Ok "ユーザーと /etc/wsl.conf を設定"

    # wsl.conf は起動時にしか読まれないので、ここで一度落とす。
    Invoke-Wsl --terminate $Distro | Out-Null
} else {
    Say "既存ディストロ '$Distro' を使用"
    # 既存ディストロで systemd が無効だと Nix の導入が失敗する。有効にするには
    # /etc/wsl.conf の書き換え + ディストロ再起動が要るので、勝手にやらず断る。
    $hasSystemd = $false
    Invoke-Wsl -d $Distro -- test -d /run/systemd/system
    if ($LASTEXITCODE -eq 0) { $hasSystemd = $true }
    if (-not $hasSystemd) {
        Warn "'$Distro' で systemd が有効になっていません (Nix の導入に必要)"
        Write-Host ""
        Write-Host "    /etc/wsl.conf に次を追記して有効化します:"
        Write-Host "        [boot]"
        Write-Host "        systemd=true"
        Write-Host ""
        $a = Read-Host "    追記してよいですか? [y/N]"
        if ($a -ne 'y' -and $a -ne 'Y') { Fail "systemd が無いと続行できません" }
        # 既存の wsl.conf を壊さないよう、退避してから追記する。
        # printf '\n...' は使わない (wsl.exe の引数リレーが \ を食う恐れ)。echo で追記。
        Invoke-Wsl -d $Distro -u root -- bash -c `
            "test -f /etc/wsl.conf && cp /etc/wsl.conf /etc/wsl.conf.ncc-backup; { echo; echo '[boot]'; echo 'systemd=true'; } >> /etc/wsl.conf"
        $script:manifest = Add-NccEntry $script:manifest @{
            type = 'wslconf'; distro = $Distro; backup = '/etc/wsl.conf.ncc-backup'
        } @('distro')
        Invoke-Wsl --terminate $Distro | Out-Null
        Ok "有効にしました (ディストロを再起動しました)"
    }
}

Save-NccManifest $manifest

# ---------------------------------------------------------------------------
# 5. WSL 内のセットアップ
# ---------------------------------------------------------------------------
Say "WSL 内のセットアップを開始 (Nix → home-manager)"
Write-Host "    初回は 5〜15 分かかります。" -ForegroundColor DarkGray
Write-Host ""

# 展開済みの setup.sh を /mnt/c/... 経由で直接叩く。これなら WSL 側に git も
# curl も無くてよい (setup.sh 自身が apt でそれらを入れてから clone する)。
$setupLin = ConvertTo-WslPath (Join-Path $src.FullName 'scripts\setup.sh')

# $args は PowerShell の自動変数なので使わない。
$setupArgs = @('bash', $setupLin, '--tarball', $TarballUrl)
if ($GitName)  { $setupArgs += @('--git-name', $GitName) }
if ($GitEmail) { $setupArgs += @('--git-email', $GitEmail) }

Invoke-Wsl -d $Distro -- @setupArgs
if ($LASTEXITCODE -ne 0) { Fail "WSL 内のセットアップに失敗しました" }

# ---------------------------------------------------------------------------
# 6. 完了
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  セットアップ完了" -ForegroundColor Green
Write-Host "  ---------------------------------------------------------------"
Write-Host "   - WezTerm を起動すると新しいシェルが開きます"
Write-Host "   - Caps Lock を素早く2回 → WezTerm の表示/非表示"
Write-Host "   - 左Shift = 英数 / 右Shift = かな"
Write-Host ""
Write-Host "   設定の更新:  WezTerm で  cd ~/dotfiles && just switch"
Write-Host "   元に戻す:    $($src.FullName)\uninstall.ps1"
Write-Host "   変更の記録:  $script:NccManifest" -ForegroundColor DarkGray
Write-Host ""
