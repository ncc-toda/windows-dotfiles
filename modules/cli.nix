{ pkgs, ... }:
{
  # Tools with dedicated home-manager modules get configured here so their
  # settings and shell integration are managed too.
  programs.bat.enable = true;
  programs.eza.enable = true;

  # lazygit: Git の TUI。`lazygit` で起動。
  programs.lazygit.enable = true;

  # yazi: 高速なターミナルファイルマネージャ。
  # enableBashIntegration が `y` 関数を定義し、yazi 終了時に
  # 「最後に居たディレクトリ」へシェルごと cd する (guide の y() 相当)。
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    shellWrapperName = "y";
  };

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
    just # コマンドランナー (justfile を実行; make の代替)

    # yazi のプレビュー/展開に使う外部ツール
    # (fd / ripgrep / fzf / jq は既に上で導入済み)
    ffmpeg # 動画サムネイル
    poppler-utils # PDF プレビュー (pdftoppm 等)
    imagemagick # 画像/フォントプレビュー
    p7zip # 圧縮ファイルの中身プレビュー
  ];
}
