#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# setup.sh — WSL 内側のセットアップ (Nix → repo → home-manager)
#
# 通常は Windows 側の install.ps1 から呼ばれるが、単体でも実行できる:
#   ./setup.sh --git-name "山田 太郎" --git-email "taro@example.com"
#
# 冪等: 何度実行してもよい。既に入っている物は入れ直さない。
# ---------------------------------------------------------------------------
set -euo pipefail

# dotfiles は git clone せず、tarball を curl で取って展開する (git 不要)。
# nix flake は「git リポジトリでないディレクトリ」なら中の全ファイルを追跡状態に
# 関係なく読むので、その場に置いた local.nix をそのまま評価でき、`git add -f` の
# ような小細工が要らない。ビルド/switch は path: 指定でこのディレクトリを指す。
# 既定は配布ブランチ 'release' (= 動作確認済み)。install.ps1 は --tarball で上書きする。
# 開発版が要るときは NCC_REPO_TARBALL=.../main.tar.gz か --tarball で渡す。
REPO_TARBALL="${NCC_REPO_TARBALL:-https://github.com/ncc-toda/windows-dotfiles/archive/refs/heads/release.tar.gz}"
REPO_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/.ncc-dotfiles/backup/$(date +%Y%m%d-%H%M%S)"
STATE_FILE="$HOME/.ncc-dotfiles/state"

GIT_NAME=""
GIT_EMAIL=""
SET_DEFAULT_SHELL="ask"

while [ $# -gt 0 ]; do
  case "$1" in
    --git-name)   GIT_NAME="${2:-}"; shift 2 ;;
    --git-email)  GIT_EMAIL="${2:-}"; shift 2 ;;
    --tarball)    REPO_TARBALL="${2:-}"; shift 2 ;;
    --set-default-shell)    SET_DEFAULT_SHELL="yes"; shift ;;
    --no-set-default-shell) SET_DEFAULT_SHELL="no";  shift ;;
    *) echo "不明な引数: $1" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m    OK: %s\033[0m\n' "$*"; }
warn() { printf '\033[33m    警告: %s\033[0m\n' "$*"; }
die()  { printf '\033[31m    エラー: %s\033[0m\n' "$*" >&2; exit 1; }

# --- 0. 前提の確認 ---------------------------------------------------------
[ "$(id -u)" -ne 0 ] || die "root では実行しないでください (学生ユーザーで実行する)"

USERNAME="$(id -un)"
# Nix の home.username は「実際のログインユーザー」と一致していなければならない。
# ここを取り違えると activation が最後の最後で落ちるので、実測値をそのまま使う。
say "ユーザー: $USERNAME ($HOME)"

# --- 1. 素の Ubuntu に無い前提ツールを入れる -------------------------------
# 新規ディストロには curl も無い。Nix とその取得に要る物だけ apt で入れる。
# git は使わない (dotfiles は tarball 取得、flake は path: 指定)。
# (これ以降のツールはすべて Nix が入れるので、apt に触るのはここだけ)
need_apt=()
for c in curl xz tar; do
  command -v "$c" >/dev/null 2>&1 || need_apt+=("$c")
done
if [ ${#need_apt[@]} -gt 0 ]; then
  say "前提ツールを導入 (curl / xz-utils / tar)"
  sudo apt-get update -qq
  sudo apt-get install -y -qq curl ca-certificates xz-utils tar
  ok "導入しました"
else
  ok "前提ツールは導入済み"
fi

# --- 2. Nix -----------------------------------------------------------------
# 既に Nix がある学生 (自分で入れた / 前回のセットアップ) の環境を壊さない。
if command -v nix >/dev/null 2>&1 || [ -e /nix/var/nix/profiles/default/bin/nix ]; then
  ok "Nix は導入済み ($(nix --version 2>/dev/null || echo '既存の /nix'))"
else
  say "Nix を導入 (Determinate Systems installer)"
  # この installer を選ぶ理由: flakes が既定で有効、かつ /nix/receipt.json を
  # 残すので `/nix/nix-installer uninstall` で完全に消せる。学生のマシンに
  # 消せない物を残さない、という配布の前提に合う。
  #
  # WSL では systemd が有効でないと nix-daemon を登録できない。install.ps1 が
  # 事前に /etc/wsl.conf へ systemd=true を書いて再起動しているが、単体実行の
  # ときのためにここでも確認する。
  if ! systemctl is-system-running >/dev/null 2>&1 && \
     ! [ -d /run/systemd/system ]; then
    die "systemd が有効になっていません。/etc/wsl.conf に以下を書き、PowerShell で
    'wsl --terminate <ディストロ名>' してから再実行してください:

        [boot]
        systemd=true"
  fi

  # ディストロを起動した直後は systemd がまだ 'starting' のことがある。その状態で
  # Determinate installer が nix-daemon を systemd 登録すると失敗しうるので、
  # running/degraded になるまで少し待つ (最大 ~40 秒)。
  if [ -d /run/systemd/system ]; then
    for _i in $(seq 1 40); do
      state=$(systemctl is-system-running 2>/dev/null || true)
      case "$state" in
        running|degraded) break ;;
      esac
      sleep 1
    done
    say "systemd 状態: ${state:-unknown}"
  fi
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm \
    || die "Nix の導入に失敗しました (学校のネットワークが塞いでいる可能性があります)"
  ok "Nix を導入しました"
fi

# 導入直後のシェルには PATH が通っていないので、その場で読み込む。
if ! command -v nix >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
fi
command -v nix >/dev/null 2>&1 || die "nix が PATH にありません。WSL を開き直して再実行してください"

# --- 3. dotfiles を取得 (curl + tar。clone しない) -------------------------
# tarball を展開して $REPO_DIR に配置する。--strip-components=1 で tarball の
# トップ (windows-dotfiles-main/) を剥がして中身を直接置く。tarball に local.nix
# は入っていないので、再実行 (更新) でも既存の local.nix は残る。
say "dotfiles を取得 (curl + tar)"
mkdir -p "$REPO_DIR"
if ! curl -fsSL "$REPO_TARBALL" | tar xz --strip-components=1 -C "$REPO_DIR"; then
  die "取得に失敗しました (ネットワーク / URL: $REPO_TARBALL)"
fi
ok "dotfiles: $REPO_DIR"

# --- 4. local.nix -----------------------------------------------------------
# マシン固有の設定。$REPO_DIR は git リポジトリではないので、その場に置くだけで
# flake (path: 指定) が読む。staging 等の小細工は不要。
#
# username / homeDirectory は必ず「今のログインユーザーの実測値」で書く。
# ここを既存ファイル任せにすると、配布リポジトリに誤って先生の local.nix
# (username=tetsuo) が紛れ込んでいた場合に、学生環境で username 不一致のまま
# activation が最後に落ちる。
#
# git の名前/メールは任意。commit する人だけが使う値なので、対話では聞かない。
# 学生は git を触らない前提で、身元が無くても環境は動く (git.nix は両方揃った
# ときだけ user.* を書く)。設定したい人は --git-name/--git-email か
# NCC_GIT_NAME/EMAIL で渡すか、後から ~/dotfiles/local.nix に追記して just switch。
# 決め方は 引数 > 既存 local.nix。行頭アンカーで拾う (^.*name だと username 行を誤って掴む)。
if [ -z "$GIT_NAME" ] && [ -f "$REPO_DIR/local.nix" ]; then
  GIT_NAME="$(sed -n 's/^[[:space:]]*name *= *"\(.*\)".*/\1/p' "$REPO_DIR/local.nix" | head -1)"
fi
if [ -z "$GIT_EMAIL" ] && [ -f "$REPO_DIR/local.nix" ]; then
  GIT_EMAIL="$(sed -n 's/^[[:space:]]*email *= *"\(.*\)".*/\1/p' "$REPO_DIR/local.nix" | head -1)"
fi
# 先生の既定値が居残っていたら、学生には使わせない。
if [ "$GIT_EMAIL" = "oda.tetsuo@nsg.gr.jp" ]; then GIT_NAME=""; GIT_EMAIL=""; fi

# git ブロックは両方揃ったときだけ書く (git.nix 側も片方だけなら無視する)。
if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
  git_block="
  git = {
    name = \"$GIT_NAME\";
    email = \"$GIT_EMAIL\";
  };"
  id_note="$GIT_NAME <$GIT_EMAIL>"
else
  git_block=""
  id_note="git 身元なし (後で ~/dotfiles/local.nix に追記して just switch)"
fi

cat > "$REPO_DIR/local.nix" <<EOF
# local.nix — このマシン固有の設定 (git 管理外 / scripts/setup.sh が生成)
{
  username = "$USERNAME";
  homeDirectory = "$HOME";$git_block
}
EOF
ok "local.nix を生成 ($USERNAME / $id_note)"

# --- 5. 既存 dotfiles の退避 -----------------------------------------------
# home-manager は `-b backup` で衝突した既存ファイルを *.backup へ逃がすが、
# その .backup が既にあると「backup file already exists」で activation ごと
# 失敗する。2 回目以降のセットアップが必ずここで詰まるので、先に日時付きの
# フォルダへ動かしておく。
mkdir -p "$HOME/.ncc-dotfiles"
moved=0
for f in "$HOME"/.bashrc.backup "$HOME"/.profile.backup "$HOME"/.bash_profile.backup \
         "$HOME"/.blerc.backup "$HOME"/.config/starship.toml.backup; do
  if [ -e "$f" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$f" "$BACKUP_DIR/" && moved=$((moved + 1))
  fi
done
if [ "$moved" -gt 0 ]; then
  ok "前回の *.backup を $BACKUP_DIR へ移動 ($moved 個)"
  echo "backup_dir=$BACKUP_DIR" >> "$STATE_FILE"
fi

# --- 6. home-manager --------------------------------------------------------
say "home-manager を適用 (初回は 5〜15 分かかります)"
# home-manager の CLI をまだ持っていないので、flake から activation package を
# 直接ビルドして起動する。`nix run home-manager/master` と違い、この repo の
# flake.lock が指す home-manager がそのまま使われるため版ズレが起きない。
# 適用後は programs.home-manager.enable により `home-manager` が PATH に入る。
#
# path: 指定にするのは $REPO_DIR が git リポジトリでないため。これで local.nix
# を含む全ファイルがそのまま評価対象になる (git 追跡の有無を問わない)。
out="$(nix build "path:$REPO_DIR#homeConfigurations.$USERNAME.activationPackage" \
        --no-link --print-out-paths)" \
  || die "ビルドに失敗しました"
HOME_MANAGER_BACKUP_EXT=backup "$out/activate" \
  || die "適用に失敗しました"
ok "適用しました"

# --- 7. AI エージェント CLI (Claude Code / opencode) -------------------------
# 学生がこの環境を気に入って「自分のベースにする」と決めたら、ここで入れた
# Claude Code / opencode を立ち上げ、付属の skill で自分の環境や既定設定を
# 取り込む――という流れを想定している。だから土台として両方を install 時に入れる。
#
# どちらも nix パッケージではなく各ベンダーの公式インストーラで入れる。自己更新
# 機構を持つので、nix で版を固定するより公式配布に任せた方が素直。最終的な置き場は
# ~/.local/bin に寄せる (hm-session-vars が PATH へ足すのはここだけ)。ネットワークが
# 塞がっていても環境全体は動くよう、失敗しても die せず warn で続行する。
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Claude Code: 公式ネイティブインストーラ。プラットフォーム別バイナリを直接落として
# ~/.local/bin/claude を作る (展開ツール不要)。command -v はこのシェルの PATH に
# ~/.local/bin が無いと拾えないので、実体の有無でも冪等判定する。
if command -v claude >/dev/null 2>&1 || [ -x "$LOCAL_BIN/claude" ]; then
  ok "Claude Code は導入済み"
else
  say "Claude Code を導入 (公式インストーラ)"
  if curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1; then
    ok "Claude Code を導入しました (初回は 'claude' でログイン)"
  else
    warn "Claude Code の導入に失敗 (ネットワーク?)。後で: curl -fsSL https://claude.ai/install.sh | bash"
  fi
fi

# opencode: 公式インストーラは ~/.opencode/bin に入れ、シェル rc へ PATH を追記
# しようとする。だが当環境の ~/.bashrc 等は nix 管理の読取専用シンボリックリンク
# なので追記は不発になる。そこで:
#   (1) INSTALL_DIR (~/.opencode/bin) を先に PATH へ載せて rc 追記を skip させる
#   (2) 展開に要る unzip/tar を拾えるよう ~/.nix-profile/bin も PATH に載せる
#       (tar はシステム側にもあるが unzip は nix 側だけ)
#   (3) 実体を ~/.local/bin に symlink して恒久的に PATH へ載せる
if command -v opencode >/dev/null 2>&1 || [ -x "$LOCAL_BIN/opencode" ]; then
  ok "opencode は導入済み"
elif [ -x "$HOME/.opencode/bin/opencode" ]; then
  # 実体は ~/.opencode/bin にあるが PATH(~/.local/bin)に載っていないケース
  # (過去に手動インストールした等)。再取得せず symlink だけ張って復旧する。
  ln -sf "$HOME/.opencode/bin/opencode" "$LOCAL_BIN/opencode"
  ok "opencode は導入済み (~/.local/bin に symlink を追加)"
else
  say "opencode を導入 (公式インストーラ)"
  if curl -fsSL https://opencode.ai/install \
       | PATH="$HOME/.opencode/bin:$HOME/.nix-profile/bin:$PATH" bash >/dev/null 2>&1 \
     && [ -x "$HOME/.opencode/bin/opencode" ]; then
    ln -sf "$HOME/.opencode/bin/opencode" "$LOCAL_BIN/opencode"
    ok "opencode を導入しました (~/.local/bin/opencode に symlink)"
  else
    warn "opencode の導入に失敗 (ネットワーク?)。後で: curl -fsSL https://opencode.ai/install | bash"
  fi
fi

# --- 8. ログインシェル ------------------------------------------------------
# この環境は bash 向け (ble.sh / starship / OSC 7 はすべて modules/shell.nix)。
# Ubuntu の既定は bash なので通常は何もすることがない。zsh 等の人にだけ効く。
current_shell="$(getent passwd "$USERNAME" | cut -d: -f7)"
if [ "${current_shell##*/}" != "bash" ]; then
  do_chsh="no"
  case "$SET_DEFAULT_SHELL" in
    yes) do_chsh="yes" ;;
    no)  warn "ログインシェルが $current_shell のままです。bash で使うには: chsh -s \$(command -v bash)" ;;
    ask)
      printf '    ログインシェルが %s です。bash に変更しますか? [y/N]: ' "$current_shell"
      read -r ans
      [ "$ans" = "y" ] || [ "$ans" = "Y" ] && do_chsh="yes"
      ;;
  esac
  if [ "$do_chsh" = "yes" ]; then
    # 戻せるように元の値を残す。
    echo "previous_shell=$current_shell" >> "$STATE_FILE"
    chsh -s "$(command -v bash)" && ok "ログインシェルを bash に変更 (次のログインから)"
  fi
else
  ok "ログインシェルは bash"
fi

echo
say "完了。WezTerm を開き直すと新しいシェルになります。"
echo "    AI エージェント: claude / opencode を導入済み (初回は 'claude' でログイン)"
echo "    設定の更新: cd ~/dotfiles && just switch"
echo "    元に戻す:   Windows 側の uninstall.ps1"
