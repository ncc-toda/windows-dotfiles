# dotfiles

Personal shell / terminal environment for **WSL (Ubuntu)**, managed declaratively
with [Nix flakes](https://nixos.wiki/wiki/Flakes) +
[home-manager](https://nix-community.github.io/home-manager/) (standalone).

Everything below is reproducible: check this repo out on a new machine, run one
command, and get the same shell.

## Layout

```
flake.nix          # inputs (nixpkgs, home-manager) + the "tetsuo" home config
home.nix           # top-level: username, stateVersion, env vars, module imports
modules/
  shell.nix        # bash + starship + fzf + zoxide + direnv + ble.sh + aliases
  cli.nix          # modern CLI tools (eza, bat, ripgrep, fd, jq, ...)
  git.nix          # git identity, delta, aliases
  windows.nix      # (WSL のみ) just switch 時に Windows 側の配置/登録を実行
windows/           # Windows ホスト側: WezTerm + Caps Lock トグル / IME Shift切替 (AHK)
justfile           # `just switch` / `just build` / `just update`
```

WSL の Linux 環境は home-manager が管理する。**Windows 本体**側は WezTerm を使い、
Caps Lock 2度押しで表示/非表示する Mac(Raycast) 相当のセットアップと、左Shift=英数 /
右Shift=かな の Mac 風 IME 切替(AutoHotkey)を用意している。
`modules/windows.nix` により、WSL 上では `just switch` が Windows 側の設定配置と
AHK 起動登録まで自動で行う（WezTerm/AutoHotkey 本体の導入だけは初回 winget で手動）。
`wezterm.lua` は Mac とも共用可能 → [`windows/README.md`](windows/README.md)。

## Usage

Apply the configuration (first run backs up existing `~/.bashrc` etc. to
`*.backup`):

```sh
just switch
# equivalent to:
home-manager switch --flake ~/dotfiles#tetsuo -b backup
```

First-time bootstrap on a fresh machine (before `home-manager` is on PATH):

```sh
nix run home-manager/master -- switch --flake ~/dotfiles#tetsuo -b backup
```

Other flows (`just` is installed by home-manager, so it's on PATH after the
first `switch`):

```sh
just                # default recipe = switch
just build          # evaluate/build without activating
just update         # bump nixpkgs + home-manager to latest, then switch
just generations    # list generations; roll back with the printed activate script
just --list         # show all recipes
```

## What's included

- **Shell:** bash with completion, sane history, `ble.sh` (autosuggestions +
  syntax highlighting), and modern aliases (`ls`→`eza`, `cat`→`bat`, ...).
- **Prompt:** [starship](https://starship.rs/).
- **Navigation:** [zoxide](https://github.com/ajeetdsouza/zoxide) (`z` / `zi`) +
  [fzf](https://github.com/junegunn/fzf).
- **Per-project env:** [direnv](https://direnv.net/) + nix-direnv.
- **CLI tools:** eza, bat, ripgrep, fd, jq, yq, delta, dust, duf, btop, ...
- **Git:** identity, aliases, delta diffs + [lazygit](https://github.com/jesseduffield/lazygit) TUI.
- **Files:** [yazi](https://github.com/sxyazi/yazi) file manager — `y` で起動し、
  終了時に居たディレクトリへシェルごと移動する。
- **cd 後に自動 ls:** `cd`/zoxide で移動すると eza で一覧表示（項目が多い時は省略）。

## Notes

- Login shell is still zsh. To make bash the default shell:
  `chsh -s "$(command -v bash)"` (log out/in afterwards).
- `nvm` is still sourced from `~/.nvm` for Node. Migrate to nix later if desired.
- Edit `modules/git.nix` to set your real git name/email.
