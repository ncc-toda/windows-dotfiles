{ pkgs, ... }:
{
  # Tools with dedicated home-manager modules get configured here so their
  # settings and shell integration are managed too.
  programs.bat.enable = true;
  programs.eza.enable = true;

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
  };

  # Everything else that just needs to be on PATH.
  home.packages = with pkgs; [
    ripgrep # rg  - fast grep
    fd # fd  - fast find
    jq # JSON processor
    yq-go # YAML/JSON processor
    tree
    htop
    btop
    dust # du replacement
    duf # df replacement
    delta # nicer git diffs (wired up in modules/git.nix)
    curl
    wget
    unzip
  ];
}
