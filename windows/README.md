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
  bootstrap.ps1     wezterm.lua をリンク配置 + caps-toggle.ahk をログイン時起動登録
```

## セットアップ

**初回のみ**、本体を winget で導入（Windows アプリなので Nix では入れられない）:

```powershell
winget install wez.wezterm
winget install AutoHotkey.AutoHotkey
```

シンボリックリンクを使うので **開発者モード**を有効化しておく
（設定 → プライバシーとセキュリティ → 開発者向け）。無い場合はコピー配置に自動フォールバック。

あとは **`make switch` だけ**。`modules/windows.nix` が WSL 上でのみ `bootstrap.ps1`
を呼び、`wezterm.lua` の配置と `caps-toggle.ahk` の起動登録を自動で行う。

bootstrap を単体で回したいとき（Windows 側だけ張り直したいなど）:

```sh
/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -ExecutionPolicy Bypass \
    -File "$(wslpath -w ~/dotfiles/windows/bootstrap.ps1)"
```

いずれも冪等。

## 使い方

- **Caps Lock を素早く2回** → WezTerm が前面に出る/引っ込む。未起動なら起動する。

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
- **見た目/フォント/透過**: `wezterm.lua`（`color_scheme` / `font` / `window_background_opacity`）。
- **起動する WSL ディストロ**: `wezterm.lua` の `default_prog`
  （既定は既定ディストロ。指定するなら `{ 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' }`）。
