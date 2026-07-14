# ターミナル環境仕様書（他マシン移植用）

この dotfiles（macOS / Nix Home Manager 管理）のターミナル環境を、別マシンで再現するための自己完結型ドキュメント。
**想定用途**: このファイルを AI エージェントに渡し、Windows + WSL + WezTerm で同等の環境を構築してもらう。

macOS 固有のツール（cmux, Ghostty, SketchyBar, JankyBorders, Karabiner, Raycast など）は移植対象外。本ドキュメントには「ターミナルの見た目」と「シェル内の体験」の再現に必要な情報のみを記載する。

---

## 1. 全体像

| 項目 | 現環境（macOS） | 移植時の対応 |
| --- | --- | --- |
| ターミナルエミュレータ | cmux（Ghostty コア内蔵）+ Ghostty | WezTerm で外観を再現（§2） |
| シェル | **bash**（zsh ではない） | WSL 側も bash を想定 |
| ライン編集拡張 | ble.sh（autosuggestion + シンタックスハイライト） | ble.sh を導入し §4 の blerc を適用 |
| プロンプト | Starship | §5 の starship.toml をそのまま使用 |
| フォント | Fira Code（ターミナル）+ Nerd Font グリフ | §3 参照 |
| テーマ | kanagawabones（Kanagawa 系） | WezTerm 組み込みの `kanagawabones` が使える |
| パッケージ管理 | Nix Home Manager + Homebrew | WSL では apt / Nix / cargo 等、入手しやすい手段で可 |

## 2. ターミナルエミュレータ外観（Ghostty 設定 → WezTerm へ変換）

現環境の Ghostty 互換設定（原文）:

```ini
theme = kanagawabones

font-family = Fira Code
font-thicken            # フォントを太めにレンダリング（macOS 固有。WezTerm では不要）

# 背景透過
background-opacity = 0.8
background-opacity-cells = true
background-blur-radius = 3

# カーソル（bar 形状 + kanagawabones の springBlue 系アクセント色）
cursor-style = bar
cursor-style-blink = true
cursor-color = #7fb4ca
shell-integration-features = no-cursor

# カーソル演出用カスタムシェーダー（装飾。再現は任意）
custom-shader = ./shaders/cursor_blaze.glsl   # カーソル移動時の花火系エフェクト
custom-shader = ./shaders/sparks.glsl
custom-shader = ./shaders/slash.glsl

# ウィンドウ
maximize = true
window-padding-x = 16
window-padding-y = 4
```

WezTerm (`wezterm.lua`) での対応の目安:

| Ghostty | WezTerm |
| --- | --- |
| `theme = kanagawabones` | `color_scheme = "kanagawabones"`（組み込み済み） |
| `font-family = Fira Code` | `font = wezterm.font_with_fallback({ "Fira Code", "Symbols Nerd Font Mono" })` |
| `background-opacity = 0.8` | `window_background_opacity = 0.8` |
| `background-blur-radius = 3` | Windows では `win32_system_backdrop = "Acrylic"` 等で近似 |
| `cursor-style = bar` + blink | `default_cursor_style = "BlinkingBar"` |
| `cursor-color = #7fb4ca` | `colors = { cursor_bg = "#7fb4ca", cursor_border = "#7fb4ca" }` |
| `window-padding-x/y = 16/4` | `window_padding = { left = 16, right = 16, top = 4, bottom = 4 }` |
| `maximize = true` | `wezterm.mux` の gui-startup で maximize |
| custom-shader（GLSL） | WezTerm に相当機能なし。省略してよい |

WSL をデフォルトで開く設定（`default_domain = "WSL:Ubuntu"` など）は移植先で適宜追加する。

## 3. フォント

| 用途 | フォント | 備考 |
| --- | --- | --- |
| ターミナル本文 | **Fira Code** | リガチャあり。Windows 側にインストール |
| Nerd Font グリフ | **Symbols Nerd Font**（`font-symbols-only-nerd-font`） | Starship の設定が Nerd Font アイコンを多用するため必須。Fira Code Nerd Font を使うか、フォールバックに Symbols Nerd Font Mono を指定 |
| エディタ系（参考） | HackGen Console NF / HackGen35 Console NF | Cursor / Zed のターミナル・エディタで使用。日本語対応 Nerd Font |

最小構成: **Fira Code Nerd Font**（または Fira Code + Symbols Nerd Font Mono フォールバック）を Windows にインストールすれば足りる。

## 4. シェル（bash + ble.sh）

### 4.1 構成

- ログインシェル・対話シェルとも **bash**。
- `.bashrc` は `~/.config/bash/bashrc.d/*.bash` を辞書順に読み込むモジュール構成。
- **ble.sh** を `--noattach` で先頭 source し、`.bashrc` 最終行で `ble-attach`（fish 風の autosuggestion とシンタックスハイライトを提供）。
- マシン固有設定は `~/.bashrc.local`（リポジトリ外・任意）。

### 4.2 シェル統合ツール（読み込み順が重要）

```bash
eval "$(starship init bash)"   # プロンプト
eval "$(direnv hook bash)"     # ディレクトリ単位の環境変数
eval "$(mise activate bash)"   # ランタイムバージョン管理
eval "$(zoxide init bash)"     # z / zi によるディレクトリジャンプ
eval "$(fzf --bash)"           # Ctrl-R: 履歴 / Ctrl-T: ファイル / Alt-C: ディレクトリ移動
corepack enable                # pnpm を Node.js 同梱の corepack 経由で有効化
```

注意: `starship init bash` は既存の `PROMPT_COMMAND` を破棄するため、プロンプトフック（§4.3）は starship 初期化より**後**に登録すること。

### 4.3 カスタム挙動

**(1) fish の chpwd 相当 — ディレクトリ移動後に自動 `ls -a`**

```bash
# cd / z の直後に ls -a を表示（コマンド実行時に出力）
cd() {
  builtin cd "$@" || return
  __autols_last_pwd="$PWD"
  ls -a
}

# zoxide の z / zi も上記 cd 関数を経由させる（zoxide init より後に定義）
if declare -F __zoxide_cd >/dev/null 2>&1; then
  __zoxide_cd() { cd -- "$@"; }
fi

# フォールバック: fzf Alt-C など cd 以外の経路で PWD が変わった場合に
# 次のプロンプトで ls -a を実行
__autols_last_pwd="$PWD"
__autols_on_prompt() {
  if [[ "$PWD" != "$__autols_last_pwd" ]]; then
    __autols_last_pwd="$PWD"
    ls -a
  fi
}
PROMPT_COMMAND="__autols_on_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
```

**(2) Ctrl-G — ghq + fzf でリポジトリへ移動**

```bash
__ghq_fzf() {
  local repo
  repo="$(ghq list -p | FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS-} ${FZF_ALT_C_OPTS-}" fzf)"
  [[ -n "$repo" ]] && cd "$repo" || return 0
}
bind -x '"\C-g": __ghq_fzf'
```

**(3) npm install ブロック — pnpm 利用の強制**

```bash
npm() {
  case "${1-}" in
    install | i | ci | add)
      echo "npm $1 is blocked. Use pnpm instead:" >&2
      echo "  pnpm $*" >&2
      return 1
      ;;
  esac
  command npm "$@"
}
```

**(4) プロンプト上のランダム画像表示（装飾・任意）**

chafa + ImageMagick で `~/.config/bash/prompt-images/` 内の画像をプロンプト描画前にタイル表示するスクリプトを `PROMPT_COMMAND` に登録している。`PROMPT_IMAGE_ENABLED=0` で無効化可能。移植は任意（画像素材が別途必要）。

### 4.4 ble.sh 設定（`~/.blerc`）— Kanagawa パレットに統一

そのまま `~/.blerc` として保存して使用可能:

```bash
# ble.sh 設定

# autosuggestion の視認性確保（透過背景対策）
ble-face auto_complete='fg=246'

# --- シンタックスハイライト（Kanagawa / kanagawabones パレットに統一） ---
# 非 truecolor 端末では ble.sh が自動で 256 色に丸める。

# コマンド名
ble-face command_file='fg=#7fb4ca'            # springBlue: 外部コマンド（カーソル色と同じアクセント）
ble-face command_builtin='fg=#ffa066'         # surimiOrange: ビルトイン
ble-face command_alias='fg=#7aa89f'           # waveAqua2: エイリアス
ble-face command_function='fg=#7e9cd8'        # crystalBlue: シェル関数
ble-face command_keyword='fg=#957fb8'         # oniViolet: if / for などの予約語
ble-face command_directory='fg=#7e9cd8,underline'
ble-face syntax_function_name='fg=#7e9cd8,bold'

# 文字列・変数・展開
ble-face syntax_quoted='fg=#98bb6c'           # springGreen: 文字列
ble-face syntax_quotation='fg=#98bb6c,bold'   # 引用符そのもの
ble-face syntax_escape='fg=#c0a36e'           # boatYellow2: エスケープ
ble-face syntax_varname='fg=#e6c384'          # carpYellow: 変数名（代入時）
ble-face syntax_param_expansion='fg=#957fb8'  # oniViolet: $VAR / ${...}
ble-face syntax_expr='fg=#d27e99'             # sakuraPink: $((...))

# 構文要素
ble-face syntax_comment='fg=#727169'          # fujiGray
ble-face syntax_delimiter='fg=#9cabca'        # springViolet2: ; | & など
ble-face syntax_glob='fg=#ff9e3b'             # roninYellow: * ? [...]
ble-face syntax_brace='fg=#9cabca'
ble-face syntax_tilde='fg=#957fb8'
ble-face syntax_document='fg=#c8c093'         # oldWhite: ヒアドキュメント
ble-face syntax_document_begin='fg=#c8c093,bold'

# エラー表示は背景色を使わず文字色のみで示す
ble-face syntax_error='fg=#e46876'            # waveRed: 未存在コマンド等
ble-face argument_error='fg=#e46876'          # waveRed: 引数エラー
ble-face filename_orphan='fg=#e46876,underline' # リンク切れ symlink

# ファイル名・引数
ble-face filename_directory='fg=#7e9cd8,underline'
ble-face filename_executable='fg=#98bb6c,underline'
ble-face filename_link='fg=#7fb4ca,underline'
ble-face filename_warning='fg=#e46876,underline'
ble-face argument_option='fg=#7aa89f'         # waveAqua2: -f --long

# 選択領域
ble-face region='bg=#2d4f67'                  # waveBlue2（Kanagawa の Visual 相当）
```

## 5. プロンプト（Starship）

配置先: `~/.config/starship.toml`。Nerd Font 必須。配色は Tokyo Night 系（`#1a1b26` / `#7aa2f7` / `#9ece6a` など）で、ターミナルテーマ（Kanagawa）とは独立にプロンプト内で完結している。

`utc_time_offset = '+9'`（JST）に注意。タイムゾーンが異なるマシンでは調整する。

そのまま使える全文:

```toml
format = """
[](fg:#7aa2f7)\
$os\
[ ](fg:#7aa2f7 bg:#1a1b26)\
$direnv\
$directory\
$git_branch\
$git_status\
$git_metrics\
[](fg:#1a1b26)\
$fill\
[](fg:#1a1b26)\
$conda\
[](fg:#9ece6a bg:#1a1b26)\
$python\
[](fg:#9ece6a)
\n$character\
"""

right_format = """
$cmd_duration
$lua
$rust
$time
"""

[os]
format = "[$symbol]($style)"
style = 'fg:#1a1b26 bg:#7aa2f7'
disabled = false

[os.symbols]
Macos = "  " # nf-fa-apple
Ubuntu = "  " # nf-linux-ubuntu
Debian = "  " # nf-linux-debian

[directory]
truncation_length = 6
truncation_symbol = ' ' # nf-fa-folder_open
truncate_to_repo = false
home_symbol = ' ~' # nf-costum-home
style = 'fg:#7aa2f7 bg:#1a1b26'
read_only = ' 󰌾 ' # nf-md-lock
read_only_style = 'fg:#f7768e bg:#1a1b26'
format = '[$path]($style)[$read_only]($read_only_style)'

[git_branch]
symbol = '  ' # nf-fa-github_alt, nf-fa-code_fork
truncation_length = 4
truncation_symbol = ''
style = 'fg:#7aa2f7 bg:#1a1b26'
format = '[  $symbol$branch(:$remote_branch)]($style)' # nf-pl-left_soft_divider

[git_status]
style = 'fg:#e0af68 bg:#1a1b26'
conflicted = '='
ahead = '⇡${count}'
behind = '⇣${count}'
diverged = '⇕'
up_to_date = '✓'
untracked = '?'
stashed = '$'
modified = '!${count}'
renamed = '»'
deleted = '✘'
format = '([\[$all_status$ahead_behind\]]($style))'

[git_metrics]
added_style = 'fg:#9ece6a bg:#1a1b26'
deleted_style = 'fg:#9ece6a bg:#1a1b26'
format = '[+$added/-$deleted]($deleted_style)'
disabled = false

[fill]
symbol = '─'
style = 'blue'

[conda]
symbol = ' ' # nf-dev-python
style = 'fg:#9ece6a bg:#1a1b26'
format = '[ $symbol$environment ]($style)'
ignore_base = false

[python]
symbol = ' ' # nf-dev-python
format = '[ ${symbol}${pyenv_prefix}(${version})(\($virtualenv\))]($style)'
pyenv_version_name = false
style = 'fg:#1a1b26 bg:#9ece6a'

[direnv]
format = '[$symbol$allowed]($style) '
style = "bold fg:#1a1b26 bg:#cba6f7"
disabled = false

[character]
success_symbol = '[❯](bold #9ece6a)'
error_symbol = '[❯](bold red)'

[cmd_duration]
min_time = 1
style = 'fg:#e0af68'
format = "[   $duration]($style)" # nf-pl-right_soft_divider, nf-mdi-clock

[lua]
symbol = "" # nf-seti-lua
format = '[  $symbol $version](blue)' # nf-pl-right_soft_divider

[rust]
symbol = "" # nf-dev-rust
format = '[  $symbol $version](red)' # nf-pl-right_soft_divider

[time]
disabled = false
style = 'fg:#73daca'
format = '[   $time]($style)' # nf-pl-right_soft_divider, nf-fa-clock_o
time_format = '%T'
utc_time_offset = '+9'
```

## 6. CLI ツール一覧

現環境で Nix により導入しているターミナル関連ツール。WSL では apt / Nix / cargo / mise 等で導入する。

### シェル体験に必須

| ツール | 役割 |
| --- | --- |
| ble.sh (blesh) | bash の autosuggestion / シンタックスハイライト |
| bash-completion | 補完定義（v2） |
| starship | プロンプト |
| zoxide | `z` / `zi` ディレクトリジャンプ |
| fzf | あいまい検索（Ctrl-R / Ctrl-T / Alt-C / Ctrl-G） |
| direnv | ディレクトリ単位の環境変数 |
| mise | ランタイムバージョン管理 |

### 日常利用ツール

| ツール | 役割 |
| --- | --- |
| git / gh / ghq | Git・GitHub CLI・リポジトリ一元管理（Ctrl-G と連携） |
| lazygit | Git TUI |
| yazi | ファイラー TUI |
| tmux | ターミナルマルチプレクサ |
| fd / ripgrep / jq / gnused | 検索・テキスト処理 |
| chafa / imagemagick / ffmpeg / poppler | 画像・メディア（yazi のプレビューとプロンプト画像表示に使用） |

### ランタイム類（参考）

nodejs 20 + corepack (pnpm) / bun / uv (Python) / rustup / openjdk 21 / shellcheck / shfmt / pre-commit

## 7. 移植時の注意（WSL + WezTerm 向け）

1. **WezTerm の設定は Windows 側**（`%USERPROFILE%\.wezterm.lua` 等）、シェル・CLI ツールは WSL 側に配置する。フォントも Windows 側にインストールする。
2. `kanagawabones` は WezTerm に組み込み済みのカラースキーム名。見つからない場合は `Kanagawa (Gogh)` で近似できる。
3. ble.sh は WSL 上で `git clone https://github.com/akinomyoga/ble.sh` からビルドするか、パッケージで導入。source パス（現環境は `~/.nix-profile/share/blesh/ble.sh`）は導入方法に合わせて変更する。読み込み順（`--noattach` で先頭、`ble-attach` を .bashrc 最終行）は必ず守る。
4. Starship の `[os.symbols]` に Ubuntu / Debian のアイコンが定義済みのため、WSL でもそのまま動く。
5. §4.3 のカスタム関数は PATH 設定（macOS 固有の `/opt/homebrew/bin` など）を除き OS 非依存。PATH 部分は移植不要。
6. SDKMAN・Kiro CLI の読み込みブロックが現環境の `.bash_profile` / `.bashrc` にあるが、これらは任意ツールなので移植対象外としてよい。
