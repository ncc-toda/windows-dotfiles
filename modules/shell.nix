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
        PROMPT_COMMAND="__osc7_cwd''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

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

      (lib.mkAfter ''
        [[ ''${BLE_VERSION-} ]] && ble-attach
      '')
    ];
  };

  # ---------------------------------------------------------------------------
  # Prompt & shell integrations (all auto-hook into bash)
  # ---------------------------------------------------------------------------
  programs.starship = {
    enable = true;
    settings = {
      # WSL's /mnt/c (Windows filesystem) is slow; the default 30ms git scan
      # times out there. Give it more headroom.
      scan_timeout = 100;
      command_timeout = 1000;
    };
  };

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
