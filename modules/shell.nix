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
