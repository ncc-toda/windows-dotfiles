{ ... }:
{
  imports = [
    ./modules/shell.nix
    ./modules/cli.nix
    ./modules/git.nix
    ./modules/windows.nix
  ];

  home.username = "tetsuo";
  home.homeDirectory = "/home/tetsuo";

  # Do not change after the first activation (matches the home-manager release
  # the config was written against). Not the version you upgrade over time.
  home.stateVersion = "25.05";

  # Common environment.
  home.sessionVariables = {
    EDITOR = "vim";
    PAGER = "less";
    LANG = "en_US.UTF-8";
  };

  # Put ~/.local/bin on PATH (used by pip/pipx and various installers).
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Lets you run `home-manager switch` without extra flags once activated.
  programs.home-manager.enable = true;
}
