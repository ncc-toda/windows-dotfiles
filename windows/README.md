# windows/ — Windows ホスト側 dotfiles

WSL 内の home-manager が管理する Linux 環境とは別レイヤー。**WezTerm** をターミナルに、
**Caps Lock 2度押しで表示/非表示にトグル**する（Mac の Raycast 相当）。

WezTerm 設定は普通のテキスト(`wezterm.lua`)なので、そのまま dotfiles 管理できる
（Windows Terminal のようなパッケージアプリ制約がない）。**同じ `wezterm.lua` を
Mac でも使える**。

```
windows/
  wezterm.lua       WezTerm 設定 (Mac/Windows 共用。Windows では既定で WSL を開く)
  caps-toggle.ahk   Caps Lock 2度押し → WezTerm を表示/非表示トグル (AutoHotkey v2)
  ime-shift.ahk     左Shift=英数 / 右Shift=かな (Mac風のIME切替。AutoHotkey v2)
  bootstrap.ps1     wezterm.lua をリンク配置 + フォント導入 + 各 .ahk をログイン時起動登録
```

## 見た目

`terminal-environment.md`（Mac 環境の仕様書）の外観を WezTerm で再現している。

- **テーマ**: `kanagawabones`（WezTerm 組み込みの Kanagawa 系）。シェルの
  シンタックスハイライト（ble.sh / `config/blerc`）とプロンプト周辺のアクセントも
  同じ Kanagawa パレット（カーソル = springBlue `#7fb4ca`）で揃えている。
- **フォント**: **Fira Code Nerd Font**（リガチャ + Nerd Font グリフ）。
  `bootstrap.ps1` が Nerd Fonts の最新リリースから Fira Code / Symbols Nerd Font を
  ユーザー領域に自動導入するので、手動インストールは不要（再ログインで全アプリに反映）。
- **プロンプト**: Starship（Tokyo Night 系。`config/starship.toml`）。WSL 側の
  home-manager が `~/.config/starship.toml` に配置する。
- **透過**: `window_background_opacity = 0.8`（WezTerm 自前のアルファ透過）。
  Windows の `win32_system_backdrop = 'Acrylic'`（DWM のぼかし）は透過が効かなく
  なる不具合が多いため使わず `'Disable'`（背後のぼかしは無し）。

## セットアップ

**初回のみ**、本体を winget で導入（Windows アプリなので Nix では入れられない）:

```powershell
winget install wez.wezterm
winget install AutoHotkey.AutoHotkey
```

シンボリックリンクを使うので **開発者モード**を有効化しておく
（設定 → プライバシーとセキュリティ → 開発者向け）。無い場合はコピー配置に自動フォールバック。

> [!IMPORTANT]
> 開発者モードが ON でも、リンク先が `\\wsl.localhost\...` の UNC パスだと管理者権限を
> 要求されて symlink 作成に失敗し、**コピー配置になる**。コピーだと `wezterm.lua` を
> 編集しても Windows 側に反映されないので、編集のたびに bootstrap の再実行が必要。
> 実体かリンクかは `ls -la /mnt/c/Users/<user>/.wezterm.lua` の先頭が `l` か `-` かで判る。

あとは **`just switch` だけ**。`modules/windows.nix` が WSL 上でのみ `bootstrap.ps1`
を呼び、`wezterm.lua` の配置と `caps-toggle.ahk` の起動登録を自動で行う。

bootstrap を単体で回したいとき（Windows 側だけ張り直したいなど）:

```sh
/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -ExecutionPolicy Bypass \
    -File "$(wslpath -w ~/dotfiles/windows/bootstrap.ps1)"
```

いずれも冪等。

## 使い方

- **Caps Lock を素早く2回** → WezTerm が前面に出る/引っ込む。未起動なら起動する。
- **左 Shift 単押し** → 英数(IME OFF)、**右 Shift 単押し** → かな(IME ON)。
  Shift を他キーと同時に押したときは従来どおり Shift 修飾として働く。

### 左Shift=英数 / 右Shift=かな (`ime-shift.ahk`)

Mac の「英数/かな」キー配置を Windows で再現する。Mac 同様**トグルではなく絶対
切り替え**（左は必ず OFF、右は必ず ON）なので、今どちらの状態か気にせず叩ける。

- 仕組み: `WM_IME_CONTROL` + `IMC_SETOPENSTATUS` を IMM32 API 経由で送り、IME の
  開閉状態を直接指定する。**キー送出ではないので IME 実装に依存しない**——
  **Google 日本語入力 / Microsoft IME / ATOK 共通で効く**。IME 側の設定変更も不要。
  （`vk16/vk1A` = VK_IME_ON/OFF は MS-IME 専用で Google IME は解釈しないため使わない。）
- 単押し判定: Shift を離した瞬間に `A_PriorKey` を見て、直前が Shift 自身なら
  単押し＝IME 切替、別キーなら修飾として使われたとみなし切替しない。`{Blind}`
  付き Down/Up なので大文字入力・範囲選択などの素の Shift 挙動は壊れない。

### ペイン/タブ操作 (tmux 風・Leader = `Ctrl+A`)

`Ctrl+A` を押してから次のキー:

| キー | 動作 |
|---|---|
| `\|` (Shift) | 横に分割 |
| `-` | 縦に分割 |
| `h` `j` `k` `l` | 左/下/上/右のペインへ移動 |
| `Shift+h/j/k/l` | ペインサイズ変更 |
| `z` | 現在のペインを最大化トグル |
| `x` | ペインを閉じる（確認あり） |
| `c` | 新しいタブ（今開いているパスで開く） |
| `n` / `p` | 次 / 前のタブ |
| `1`〜`9` | その番号のタブへ |
| `Shift+S` | セッションを手動保存 |
| `r` | セッションを復元（ファジー選択） |

Leader なしの単発キー:

| キー | 動作 |
|---|---|
| `Ctrl+W` | ペインを削除（即時。※シェルの単語削除を奪う） |
| `Ctrl+T` | 新しいタブ（今開いているパスで開く。※readline の transpose を奪う） |
| `Ctrl+D` / `Ctrl+Shift+D` | 左右 / 上下に分割 |
| `Ctrl+[` / `Ctrl+]` | 前 / 次のペインへ |
| `Ctrl+Shift+P` | コマンドパレット（メニュー相当） |

## 前提: この PC は CapsLock → F13 リマップ済み

このマシンは**物理 CapsLock がレジストリで F13 にリマップ**されている
（`move cursor.ahk` が `F13 & …` を修飾キーに使うため）。よって AHK からは
CapsLock ではなく **F13** が届くので、`caps-toggle.ahk` は **F13 の2度押し**を見る。

- リマップ場所:
  `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout` の `Scancode Map`
  （`… 02 00 00 00 64 00 3A 00 …` = `3A`(CapsLock)→`64`(F13)）。
- `caps-toggle.ahk` は `~*F13`（`~`=信号を素通し）で拾うため、`move cursor.ahk` の
  F13 修飾機能を壊さない。押しっぱなしのオートリピートも `held` ガードで無視する。

**別マシンで使う場合**: CapsLock→F13 リマップが無いなら、`caps-toggle.ahk` の `F13`
を `CapsLock` に置き換える（`~*F13` → `*CapsLock`、単押し大文字ロックを消すなら
先頭に `SetCapsLockState "AlwaysOff"` を足す）。または同じ Scancode Map を入れて再起動する。

## Mac との共用

Mac では同じ `wezterm.lua` を `~/.wezterm.lua` にリンクすれば同一設定で使える:

```sh
ln -sf ~/dotfiles/windows/wezterm.lua ~/.wezterm.lua
```

（トグルは Mac 側は従来どおり Raycast のままでよい。`wezterm.lua` は
`target_triple` で OS を判定し、WSL 起動などは Windows のときだけ有効になる。）

## カスタマイズ

- **トグルの猶予時間**: `caps-toggle.ahk` の `300`(ms)。
- **隠し方**: 既定は最小化(`WinMinimize`)。Alt+Tab からも消したいなら `WinHide`/`WinShow` に。
- **見た目/フォント/透過**: `wezterm.lua`（`color_scheme` / `font` / `window_background_opacity`。
  数値を下げるほど透ける）。ぼかしは Windows=`win32_system_backdrop`、Mac=`macos_window_background_blur`。
- **起動時の最大化**: `gui-startup` イベントで開いたウィンドウを `:maximize()` している。
  最大化をやめたい場合はその行を消す。
- **起動する WSL ディストロ**: `wezterm.lua` は `wezterm.default_wsl_domains()` で
  インストール済みディストロを列挙し、先頭を既定にする。特定のディストロに固定するなら
  `config.default_domain = 'WSL:Ubuntu'` のように名前指定する（名前は上記列挙の値）。

## セッション保持（前回のパス/レイアウト復元）

`wezterm.lua` は [resurrect.wezterm](https://github.com/MLFlexer/resurrect.wezterm) プラグインで
**タブ/ペイン/開いていたパスを復元**する。

- **仕組み**: 60 秒ごとに状態をスナップショット保存し、起動時に直近の状態を自動復元する。
  手動保存/復元は `Ctrl+A → Shift+S` / `Ctrl+A → r`。
- **初回起動時のみ**、プラグイン本体を GitHub から自動取得する（ネット接続が必要。以降はキャッシュ）。
  取得に失敗しても本体設定は死なず、復元機能だけ無効になる（`pcall` でガード）。
- **パス追従の土台**: 分割/新タブ/復元が「今開いているパス」で開くのは、bash が
  **OSC 7 で現在ディレクトリを WezTerm に通知**しているため（`modules/shell.nix` で設定）。
  これが無いと WezTerm は cwd を追跡できず、常にホームで開く。
- **復元されないもの**: 復元されるのはレイアウトと cwd だけで、ペインで動いていた
  プロセス（`claude`、`vim` 等）は復元されず、そのパスでシェルが開くだけ。
- **保存するのは workspace 状態のみ**（`save_windows`/`save_tabs` は `false`）。これらは
  ウィンドウ名・タブ名ごとに別ファイルを作るため、Claude Code のようにタイトルを
  書き換え続けるアプリがあると状態ファイルが際限なく増える。workspace 状態だけで
  ウィンドウ/タブ/ペイン/cwd はすべて含まれるので復元には十分。
- **起動時復元の要**: プラグインは復元対象を `state/current_state` ファイルから読むが、
  このファイルは**プラグイン側では書かれない**（README: "you must include a way to write
  the current workspace"）。`wezterm.lua` が保存のたびに `write_current_state()` で
  書いている。これが無いと 0 バイトのままで永久に復元されない。
