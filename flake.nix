{
  description = "ncc terminal environment (WSL / Ubuntu / home-manager standalone)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # マシン固有の設定 (ユーザー名 / git identity) は local.nix に分離する。
      # scripts/setup.sh が local.nix.example から生成し、`git add -f` で index に
      # 載せる (flake は git が追跡しているファイルしか見ないため)。
      local =
        if builtins.pathExists ./local.nix then
          import ./local.nix
        else
          throw ''
            local.nix がありません。

            初回セットアップなら scripts/setup.sh を実行してください:
              ~/dotfiles/scripts/setup.sh

            local.nix はあるのにこのエラーが出る場合、git の index に載っていません
            (flake は git 管理下のファイルしか見ません)。次で解決します:
              git -C ~/dotfiles add -f local.nix
          '';
    in
    {
      # 設定名 = ユーザー名。よって学生も先生も同じコマンドで適用できる:
      #   home-manager switch --flake ~/dotfiles#$(id -un) -b backup
      homeConfigurations.${local.username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
        extraSpecialArgs = { inherit local; };
      };
    };
}
