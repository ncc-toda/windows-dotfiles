# windows-dotfiles

**WSL (Ubuntu) + Windows ホスト** のターミナル環境一式。Nix flakes +
[home-manager](https://nix-community.github.io/home-manager/)（standalone）で
宣言的に管理し、**コマンド1つ**で新しいマシンに再現できる。学生への配布を前提に、
「マシンを書き換える部分は退避 + 記録して元に戻せる」ように作ってある。

## 入れる（学生向け）

PowerShell で1行:

```powershell
irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/v1.0/install.ps1 | iex
```

詳しい手順・つまずき・アンインストールは **[INSTALL.md](INSTALL.md)** を参照。

## 配布はタグ (リリース) から

学生が叩く URL は `main` ではなく**固定タグ `v1.0`** を指す。`main` は「触った瞬間に
全学生のマシンで実行される生きた配線」なので、いつ導入しても同じ検証済みスナップ
ショットを踏むよう、配布はタグに固定してある。`install.ps1` / `uninstall.ps1` 内の
`$Ref` も同じタグを指すので、入口スクリプトも中身 (dotfiles・state.ps1) も同一 ref に
揃う。

新版を出す手順:

1. `main` で変更 → 実機で確認
2. 入口の参照を新タグに更新: `install.ps1` / `uninstall.ps1` の `$Ref`、README /
   INSTALL の URL を `vX.Y` に
3. コミットして `git tag -a vX.Y -m ... && git push origin vX.Y`
4. 学生へ新しい URL を周知

`just upgrade` は `main` (最新の開発版) を取り込むので、検証済みの版だけ使いたい間は
使わない。安定して更新したいときは新しいタグの `install.ps1` を叩き直す。

## 配布の設計（どうやって「壊さない」か）

学生のマシンに触る操作は2層に分かれる。

- **WSL/Linux 側**は元から安全。Nix はパッケージを `/nix/store` に隔離し、
  home-manager は既存の `~/.bashrc` 等を `-b backup` で退避し、`home-manager
  generations` でロールバックできる。さらに **「授業専用の WSL ディストロを新規
  作成」** を既定にしており、これを選べば学生の既存環境には一切触れず、不要になれば
  `wsl --unregister` で跡形なく消える。
- **Windows ホスト側**は隔離できない（WezTerm / フォント / スタートアップ登録 /
  winget）。そこで **触った物を全部 `manifest.json` に記録**し、既存ファイルは
  日時付きフォルダへ退避する。`uninstall.ps1` がその記録を逆再生して原状復帰する。
  「自分が入れた物か、学生が元から持っていた物か」を記録しているので、人の物を
  巻き込んで消さない。

記録の置き場: `%LOCALAPPDATA%\ncc-dotfiles\`（`manifest.json` と `backup\<日時>\`）。

## Layout

```
install.ps1        学生の入り口。irm | iex で起動。全体の面倒を見る。
uninstall.ps1      manifest を逆再生して原状復帰。
local.nix.example  マシン固有設定 (ユーザー名 / git identity) の雛形。

flake.nix          inputs (nixpkgs, home-manager)。設定名 = local.nix の username。
home.nix           top-level: username/home は local.nix から、env vars、module imports。
local.nix          (git 管理外・setup.sh が生成) このマシンの username と git identity。
modules/
  shell.nix        bash + starship + fzf + zoxide + direnv + ble.sh + aliases
  cli.nix          modern CLI tools (eza, bat, ripgrep, fd, jq, ...)
  git.nix          git identity (local.nix 参照。最小構成)
  windows.nix      (WSL のみ) just switch 時に Windows 側 bootstrap.ps1 を呼ぶ
scripts/
  setup.sh         WSL 内側: Nix 導入 → tarball 取得(curl) → local.nix 生成 → home-manager
  teardown.sh      WSL 内側の後始末 (既存ディストロに入れた場合の uninstall で使用)
windows/
  wezterm.lua      WezTerm 設定 (Mac/Windows 共用)
  caps-toggle.ahk  Caps Lock 2度押しトグル (F13/CapsLock を自動判別)
  ime-shift.ahk    左Shift=英数 / 右Shift=かな (IMM32 API 経由。IME 非依存)
  bootstrap.ps1    Windows 側の配置 + フォント + AHK 登録 (manifest 記録つき)
  state.ps1        manifest の読み書き (bootstrap/install/uninstall が共用)
justfile           `just switch` / `just build` / `just update` / `just upgrade`
```

## マシン固有設定（local.nix）

ユーザー名と git の名前/メールは人ごとに違うので `local.nix` に分離してある
（`.gitignore` 済み）。`scripts/setup.sh` が `local.nix.example` を雛形に生成する。
後から変えるときは `local.nix` を直接編集して `just switch`。

flake の参照は `path:` 指定（justfile / setup.sh とも）。`path:` は対象を git
リポジトリとして扱わず中の全ファイルをそのまま読むので、**追跡外の `local.nix` も
そのまま評価対象になる**（`git add -f` のような小細工は不要）。学生の `~/dotfiles`
は tarball 展開の非 git ディレクトリ、開発者のは git リポジトリだが、`path:` なら
どちらでも同じに動く。逆に `.#…`（path: 無し）で評価すると git リポジトリでは
追跡外の `local.nix` が見えず失敗する。

学生の取得は **git clone せず tarball を curl で展開**する。よって WSL 側に git は
不要（`curl` / `xz` / `tar` のみ。これらは Nix 導入にも要る）。dotfiles 自体の更新は
`just upgrade`（tarball 取り直し）。`just update` は nix inputs の更新。

## 開発・保守

```sh
just                # = just switch。設定を適用 (初回は既存 dotfiles を退避)
just build          # 評価/ビルドだけ (適用しない)。CI 的な確認に。
just update         # nixpkgs + home-manager を最新へ、その後 switch
just generations    # 世代一覧 / ロールバック
just --list         # 全レシピ
```

設定名はハードコードせず `id -un`（実ユーザー名）で解決するので、誰の環境でも
同じレシピが動く。

## 環境差異への対応（設計メモ）

配布先ごとの差を吸収するために入れてある工夫:

- **Caps Lock → F13 リマップの有無**: `caps-toggle.ahk` が起動時に Scancode Map を
  読んで、F13 が来るマシンと CapsLock が来るマシンのどちらかに動的にバインドする。
  片方に決め打ちすると、もう片方で「2度押ししても無反応」になるのを防ぐ。
- **IME の種類**: `ime-shift.ahk` は `WM_IME_CONTROL` + `IMC_SETOPENSTATUS` を IMM32
  に直接送る。キー送出ではないので Google 日本語入力 / MS-IME / ATOK 共通で効き、
  IME が1つも無い英語環境では無害に何もしない。
- **AutoHotkey v1 しか無い**: v1/v2 は併存できる。bootstrap は v2 だけを探して使い、
  学生の v1 を取り上げない。
- **開発者モードが無い / WSL の UNC パス**: symlink が張れない環境では自動でコピー
  配置にフォールバックする。
- **Nix が既に入っている**: `setup.sh` は既存の Nix を壊さず再利用する。
- **既存 `.backup` の衝突**: `setup.sh` は home-manager が失敗する前に古い `*.backup`
  を日時付きフォルダへ退避する。
- **素の Ubuntu に curl が無い**: `setup.sh` が Nix より前に apt で `curl`/`xz`/`tar`
  だけ入れる（git は使わない）。
- **学校ネットワークが GitHub を塞ぐ**: フォント取得等は失敗しても警告のみでシェル
  自体は動く。取得は Windows 側で済ませ、WSL 側にツールが無くても進む設計。
- **PowerShell 5.1 + 日本語**: 配布 `.ps1` は UTF-8 **BOM 付き**（`.gitattributes` で
  `-text` にして保護）。BOM が無いと 5.1 がコメントを cp932 と誤読して構文が壊れる。

## 見た目・キー操作の詳細

Windows ホスト側（WezTerm / テーマ / フォント / ペイン操作 / セッション復元）は
[`windows/README.md`](windows/README.md) に、元となった Mac 環境の仕様は
[`terminal-environment.md`](terminal-environment.md) にある。

## 中身（何が入るか）

- **Shell:** bash + 補完 + `ble.sh`（補完候補 + シンタックスハイライト）+ 近代的な
  alias（`ls`→`eza`, `cat`→`bat` …）
- **Prompt:** [starship](https://starship.rs/)
- **Navigation:** [zoxide](https://github.com/ajeetdsouza/zoxide)（`z`/`zi`）+ fzf
- **Per-project env:** direnv + nix-direnv
- **CLI:** eza, bat, ripgrep, fd, jq, yq, dust, duf, btop, …
- **Git:** 最小構成 (身元は任意 + 安全側の既定のみ) + [lazygit](https://github.com/jesseduffield/lazygit)
- **Files:** [yazi](https://github.com/sxyazi/yazi)（`y` で起動、終了時のディレクトリへ cd）
- **cd 後に自動 ls**（項目が多い時は省略）
