# windows-dotfiles

**WSL (Ubuntu) + Windows ホスト**のターミナル環境一式。Nix flakes +
[home-manager](https://nix-community.github.io/home-manager/)（standalone）で宣言的に
管理し、**コマンド1つ**で新しいマシンに再現できる。学生配布を前提に、マシンを書き換える
部分は退避・記録して元に戻せるようにしてある。

## 入れる（学生向け）

PowerShell で1行:

```powershell
irm https://raw.githubusercontent.com/ncc-toda/windows-dotfiles/release/install.ps1 | iex
```

手順・つまずき・アンインストールは **[INSTALL.md](INSTALL.md)**、使い方の早見表は
**[CHEATSHEET.md](CHEATSHEET.md)**。

## 配布は `release` ブランチから

学生が踏むのは `main` ではなく**固定ブランチ `release`**。`main` は「触った瞬間に全学生の
マシンで走る生きた配線」になってしまうので、`main` = 開発/検証、`release` = 検証済みの最新
スナップショット、と役割を分ける。学生 URL・`$Ref`（`install.ps1` / `uninstall.ps1`）・
`just upgrade` の取得先はすべて `release` 固定で、**一度決めたら二度と書き換えない**。

新版を出す（リリース）手順:

1. `main` で変更 → 実機確認
2. `main` を `release` へ進める（fast-forward）: `git switch release && git merge --ff-only main && git push`

これだけ。タグ切り・URL 書き換え・学生への再周知は不要（URL が不変なので、学生は同じ
インストーラを叩き直せば最新の検証版になる）。`just upgrade` も `release` を引くので、
学生の更新は常に検証済みの版になる。記録やロールバック用に節目で `vX.Y` タグを併用するのは
任意（`just upgrade v1.2` のように過去の版を指定して取り直せる）。

## どうやって「壊さない」か

学生のマシンに触る操作は2層に分かれる。

- **WSL/Linux 側**は元から安全。Nix はパッケージを `/nix/store` に隔離、home-manager は
  既存の `~/.bashrc` 等を `-b backup` で退避し `home-manager generations` でロールバック
  できる。既定は**授業専用の WSL ディストロを新規作成**で、既存環境に一切触れず、不要に
  なれば `wsl --unregister` で跡形なく消える。
- **Windows ホスト側**は隔離できない（WezTerm / フォント / スタートアップ登録 / winget）。
  触った物を全部 `manifest.json` に記録し、既存ファイルは日時付きフォルダへ退避、
  `uninstall.ps1` がそれを逆再生して原状復帰する。「自分が入れた物か学生の物か」を記録
  するので、人の物を巻き込んで消さない。

記録先: `%LOCALAPPDATA%\ncc-dotfiles\`（`manifest.json` と `backup\<日時>\`）。

## Layout

```
install.ps1        学生の入り口。irm | iex で起動。全体の面倒を見る。
uninstall.ps1      manifest を逆再生して原状復帰。
local.nix.example  マシン固有設定 (ユーザー名 / git identity) の雛形。

flake.nix          inputs (nixpkgs, home-manager)。設定名 = local.nix の username。
home.nix           top-level: username/home は local.nix から、env vars、module imports。
local.nix          (git 管理外・setup.sh が生成) このマシンの username と git identity。
modules/
  shell.nix        bash + starship + fzf + zoxide + direnv + ble.sh
  cli.nix          modern CLI tools (ripgrep, fd, tree, btop, ...)
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

ユーザー名と git の名前/メールは人ごとに違うので `local.nix`（`.gitignore` 済み）に分離。
`setup.sh` が `local.nix.example` を雛形に生成する。後から変えるなら直接編集して
`just switch`。

flake の参照は全て `path:` 指定。`path:` は対象を git 扱いせず中の全ファイルを読むので、
**追跡外の `local.nix` もそのまま評価される**（`.#…` だと git リポジトリで追跡外ファイルが
見えず失敗する）。学生の `~/dotfiles` は tarball 展開の非 git ディレクトリなので、取得は
**git clone せず curl で展開**する（WSL 側に git 不要、`curl`/`xz`/`tar` のみ）。dotfiles の
更新は `just upgrade`（tarball 取り直し）、nix inputs の更新は `just update`。

## 開発・保守

```sh
just             # = just switch。適用 (初回は既存 dotfiles を退避)
just build       # 評価/ビルドだけ (適用しない)
just update      # nixpkgs + home-manager を最新化して switch
just generations # 世代一覧 / ロールバック
just --list      # 全レシピ
```

設定名は `id -un`（実ユーザー名）で解決するので、誰の環境でも同じレシピが動く。

## 環境差異への対応（設計メモ）

- **Caps Lock → F13 リマップの有無**: `caps-toggle.ahk` が起動時に Scancode Map を読み、
  F13 が来るマシンと CapsLock が来るマシンのどちらかに動的にバインドする。
- **IME の種類**: `ime-shift.ahk` は `IMC_SETOPENSTATUS` を IMM32 に直接送るので Google
  日本語入力 / MS-IME / ATOK 共通で効き、IME 無しの環境では無害。
- **AutoHotkey v1 しか無い**: v2 だけを探して使い、学生の v1 は取り上げない。
- **symlink 不可（開発者モード無し / UNC パス）**: 自動でコピー配置にフォールバック。
- **Nix が既に入っている**: 壊さず再利用する。
- **既存 `*.backup` の衝突**: home-manager が失敗する前に日時付きフォルダへ退避。
- **素の Ubuntu に curl が無い**: Nix より前に apt で `curl`/`xz`/`tar` だけ入れる。
- **学校ネットが GitHub を塞ぐ**: フォント取得等は失敗しても警告のみでシェルは動く。
- **PowerShell 5.1 + 日本語**: 配布 `.ps1` は UTF-8 **BOM 付き**（`.gitattributes` で
  `-text`）。BOM が無いと 5.1 がコメントを cp932 と誤読して構文が壊れる。

## 詳細ドキュメント

- 使い方・キー操作の早見表: [`CHEATSHEET.md`](CHEATSHEET.md)
- Windows ホスト側（WezTerm / テーマ / フォント / セッション復元）: [`windows/README.md`](windows/README.md)
- 元となった Mac 環境の仕様: [`terminal-environment.md`](terminal-environment.md)

## 中身（何が入るか）

- **Shell:** bash + 補完 + `ble.sh`（補完候補 + シンタックスハイライト）
- **Prompt:** [starship](https://starship.rs/)
- **Navigation:** [zoxide](https://github.com/ajeetdsouza/zoxide)（`z`/`zi`）+ fzf
- **Per-project env:** direnv + nix-direnv
- **CLI:** ripgrep, fd, tree, btop, htop, …
- **Git:** 最小構成 (身元は任意 + 安全側の既定のみ) + [lazygit](https://github.com/jesseduffield/lazygit)
- **Files:** [yazi](https://github.com/sxyazi/yazi)（`y` で起動、終了時のディレクトリへ cd）
- **cd 後に自動 ls**（項目が多い時は省略）
