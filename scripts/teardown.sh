#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# teardown.sh — 既存ディストロに入れた場合の WSL 側後始末
#
# 「授業専用ディストロ」を作った場合はディストロごと wsl --unregister するので
# これは不要。既存ディストロに入れた場合だけ uninstall.ps1 から呼ばれる。
#
# やること: home-manager を外す → setup.sh が退避した dotfiles を戻す →
#           必要なら Nix を消す → chsh を戻す。
# ---------------------------------------------------------------------------
set -uo pipefail   # -e は付けない: 1 個外し損ねても最後まで後始末を続けたい

REMOVE_NIX="no"
[ "${1:-}" = "--remove-nix" ] && REMOVE_NIX="yes"

STATE_FILE="$HOME/.ncc-dotfiles/state"
say()  { printf '\033[36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m    OK: %s\033[0m\n' "$*"; }
warn() { printf '\033[33m    警告: %s\033[0m\n' "$*"; }

# nix / home-manager を PATH に載せる (非対話シェルだと読まれていない)。
if ! command -v nix >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
fi
export PATH="$HOME/.nix-profile/bin:$PATH"

# --- 1. home-manager を外す ------------------------------------------------
# これで managed な ~/.bashrc 等が消え、home-manager が -b backup で退避して
# いた元ファイル (*.backup) がある場合はそれが戻る土台ができる。
if command -v home-manager >/dev/null 2>&1; then
  say "home-manager を削除"
  yes | home-manager uninstall >/dev/null 2>&1 || warn "home-manager uninstall でエラー (続行)"
  ok "削除しました"
else
  warn "home-manager が見つかりません (既に消えている?)"
fi

# --- 2. setup.sh が退避した dotfiles を戻す --------------------------------
# setup.sh は衝突しそうな *.backup を $HOME/.ncc-dotfiles/backup/<日時>/ へ
# 動かしていた。home-manager を外した「今」なら書き戻せる。
if [ -f "$STATE_FILE" ]; then
  bdir="$(grep '^backup_dir=' "$STATE_FILE" | tail -1 | cut -d= -f2-)"
  if [ -n "${bdir:-}" ] && [ -d "$bdir" ]; then
    say "退避していた設定を復元: $bdir"
    for f in "$bdir"/*; do
      [ -e "$f" ] || continue
      base="$(basename "$f")"
      case "$base" in
        starship.toml) dest="$HOME/.config/starship.toml" ;;
        *)             dest="$HOME/$base" ;;
      esac
      mkdir -p "$(dirname "$dest")"
      mv "$f" "$dest" && ok "復元: $dest"
    done
  fi

  # chsh を元に戻す。
  prev="$(grep '^previous_shell=' "$STATE_FILE" | tail -1 | cut -d= -f2-)"
  if [ -n "${prev:-}" ] && [ -x "$prev" ]; then
    say "ログインシェルを $prev に戻す"
    chsh -s "$prev" && ok "戻しました (次のログインから)"
  fi
fi

# --- 3. repo -------------------------------------------------------------
if [ -d "$HOME/dotfiles/.git" ]; then
  say "\$HOME/dotfiles を削除"
  rm -rf "$HOME/dotfiles" && ok "削除しました"
fi

# --- 4. Nix (任意) ---------------------------------------------------------
# 既定では消さない。学生が別用途で Nix を使っているかもしれず、消すと巻き添えに
# なるため。--remove-nix を明示したときだけ、Determinate の公式アンインストーラで
# 完全に除去する (/nix ごと消える)。
if [ "$REMOVE_NIX" = "yes" ]; then
  if [ -x /nix/nix-installer ]; then
    say "Nix を削除 (Determinate uninstaller)"
    sudo /nix/nix-installer uninstall --no-confirm && ok "削除しました"
  else
    warn "Determinate の uninstaller が無いため Nix は残します (手動で削除してください)"
  fi
fi

# 後始末の記録も消す。
rm -rf "$HOME/.ncc-dotfiles"

say "WSL 側の後始末が完了しました。"
