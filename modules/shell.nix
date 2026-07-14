{ pkgs, lib, ... }:
{
  # ---------------------------------------------------------------------------
  # bash — the primary interactive shell
  # ---------------------------------------------------------------------------
  programs.bash = {
    enable = true;
    enableCompletion = true;

    # History behaviour.
    historyControl = [ "ignoredups" "ignorespace" ];
    historyFileSize = 100000;
    historySize = 50000;

    shellAliases = {
      # Modern CLI replacements.
      ls = "eza --group-directories-first";
      ll = "eza -l --git --group-directories-first";
      la = "eza -la --git --group-directories-first";
      lt = "eza --tree --level=2";
      cat = "bat --paging=never";
      grep = "grep --color=auto";

      # Quality-of-life.
      ".." = "cd ..";
      "..." = "cd ../..";
      gs = "git status";
      gd = "git diff";
      gl = "git log --oneline --graph --decorate -20";
    };

    # ble.sh gives bash autosuggestions + syntax highlighting (the bash answer
    # to zsh-autosuggestions / zsh-syntax-highlighting). It must be sourced
    # first and attached last, so it brackets the rest of the init.
    initExtra = lib.mkMerge [
      (lib.mkBefore ''
        # ble.sh: autosuggestions + syntax highlighting (interactive shells only)
        [[ $- == *i* ]] && source "${pkgs.blesh}/share/blesh/ble.sh" --noattach
      '')

      ''
        # nvm (kept from the previous setup; migrate node to nix later if desired)
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

        # WezTerm へ現在ディレクトリを OSC 7 で通知する。これにより WezTerm 側で
        # 「分割 / 新タブ / 新規ウィンドウ」を今開いているパスで開けるようになり、
        # resurrect のセッション復元もこのパス情報を使う。ble.sh 併用時も
        # PROMPT_COMMAND は尊重されるので両対応。
        __osc7_cwd() {
          printf '\e]7;file://%s%s\e\\' "''${HOSTNAME:-localhost}" "$PWD"
        }

        # WezTerm のタブ名用に「GitHub リポジトリ名」を user var で通知する。
        # remote origin の URL からリポジトリ名を取り出し、remote が無ければトップ
        # レベルのディレクトリ名を使う。リポジトリ外なら空文字を送る(タブ側は空なら
        # 「開いているパス」にフォールバックする)。SetUserVar は値を base64 で渡す。
        __wezterm_repo() {
          local repo url top
          url=$(git config --get remote.origin.url 2>/dev/null)
          if [[ -n $url ]]; then
            repo=''${url##*/}; repo=''${repo%.git}
          elif top=$(git rev-parse --show-toplevel 2>/dev/null); then
            repo=''${top##*/}
          fi
          printf '\e]1337;SetUserVar=%s=%s\e\\' WEZTERM_REPO \
            "$(printf %s "''${repo:-}" | base64 | tr -d '\n')"
        }
        PROMPT_COMMAND="__osc7_cwd; __wezterm_repo''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

        # cd 後に自動で一覧表示 (zsh の chpwd + eza フック相当)。
        # 項目が多いディレクトリでは一覧を省略して圧迫を防ぐ。
        __auto_ls() {
          local n
          n=$(command ls -A1 2>/dev/null | wc -l)
          if (( n > 100 )); then
            printf '  %s  (%d items — listing skipped)\n' "$PWD" "$n"
          else
            eza --group-directories-first --icons=auto --git
          fi
        }
        if [[ ''${BLE_VERSION-} ]]; then
          # ble.sh の CHPWD フック: cd/zoxide などで PWD が変わった時だけ発火。
          blehook CHPWD+=__auto_ls
        else
          # ble.sh 非使用時のフォールバック: PROMPT_COMMAND で PWD 変化を検出。
          __auto_ls_last="$PWD"
          __auto_ls_prompt() {
            [[ "$PWD" != "$__auto_ls_last" ]] && { __auto_ls_last="$PWD"; __auto_ls; }
          }
          PROMPT_COMMAND="__auto_ls_prompt''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
        fi
      ''

      # ble-attach は「全部のセットアップが終わった一番最後」に呼ぶ必要がある。
      # ここが早すぎると、ble.sh がアタッチした時点の PS1(= bash 既定の
      # \u@\h:\w\$)で最初のプロンプトを描いてしまい、starship のプロンプトは
      # 次の描画(= Enter を叩いた後)まで出ない。結果「WezTerm 起動直後は素の
      # プロンプトが出て、Enter を押すと starship に変わる」= WSL が起動して
      # いないように見える症状になる。
      # home-manager の各連携は initExtra を以下の順序値で注入する:
      #   direnv = mkAfter(1500) / starship = mkOrder 1900 / zoxide = mkOrder 2000
      # lib.mkAfter(1500) だと starship/zoxide より前に来てしまうため、それらより
      # 大きい mkOrder 2100 で「全連携の後」に確実に ble-attach させる。
      (lib.mkOrder 2100 ''
        [[ ''${BLE_VERSION-} ]] && ble-attach
      '')
    ];
  };

  # ble.sh 設定 (~/.blerc)。ble.sh が起動時に自動読込する。配色は Kanagawa 系で
  # kanagawabones テーマ (WezTerm 側) と揃えたシンタックスハイライト。
  home.file.".blerc".source = ../config/blerc;

  # ---------------------------------------------------------------------------
  # Prompt & shell integrations (all auto-hook into bash)
  # ---------------------------------------------------------------------------
  # starship 本体の有効化 (bash への `starship init` 注入) は home-manager が行い、
  # 設定は Tokyo Night 系の raw TOML (config/starship.toml) をそのまま配置する。
  # settings を空にしておくと home-manager は starship.toml を生成しないので、
  # xdg.configFile と衝突しない。
  programs.starship.enable = true;
  xdg.configFile."starship.toml".source = ../config/starship.toml;

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = [ "--cmd cd" ]; # `cd` becomes zoxide-powered
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
  };
}
