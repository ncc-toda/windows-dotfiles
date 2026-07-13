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
  windows.nix      # (WSL のみ) make switch 時に Windows 側の配置/登録を実行
windows/           # Windows ホスト側: WezTerm + Caps Lock 2度押しトグル (AHK)
Makefile           # `make switch` / `make build` / `make update`
```

WSL の Linux 環境は home-manager が管理する。**Windows 本体**側は WezTerm を使い、
Caps Lock 2度押しで表示/非表示する Mac(Raycast) 相当のセットアップを用意している。
`modules/windows.nix` により、WSL 上では `make switch` が Windows 側の設定配置と
AHK 起動登録まで自動で行う（WezTerm/AutoHotkey 本体の導入だけは初回 winget で手動）。
`wezterm.lua` は Mac とも共用可能 → [`windows/README.md`](windows/README.md)。

## Usage

Apply the configuration (first run backs up existing `~/.bashrc` etc. to
`*.backup`):

```sh
make switch
# equivalent to:
home-manager switch --flake ~/dotfiles#tetsuo -b backup
```

First-time bootstrap on a fresh machine (before `home-manager` is on PATH):

```sh
nix run home-manager/master -- switch --flake ~/dotfiles#tetsuo -b backup
```

Other flows:

```sh
make build          # evaluate/build without activating
make update         # bump nixpkgs + home-manager to latest, then `make switch`
make generations    # list generations; roll back with the printed activate script
```

## What's included

- **Shell:** bash with completion, sane history, `ble.sh` (autosuggestions +
  syntax highlighting), and modern aliases (`ls`→`eza`, `cat`→`bat`, ...).
- **Prompt:** [starship](https://starship.rs/).
- **Navigation:** [zoxide](https://github.com/ajeetdsouza/zoxide) (as `cd`) +
  [fzf](https://github.com/junegunn/fzf).
- **Per-project env:** [direnv](https://direnv.net/) + nix-direnv.
- **CLI tools:** eza, bat, ripgrep, fd, jq, yq, delta, dust, duf, btop, ...
- **Git:** identity, aliases, delta diffs.

## Notes

- Login shell is still zsh. To make bash the default shell:
  `chsh -s "$(command -v bash)"` (log out/in afterwards).
- `nvm` is still sourced from `~/.nvm` for Node. Migrate to nix later if desired.
- Edit `modules/git.nix` to set your real git name/email.
