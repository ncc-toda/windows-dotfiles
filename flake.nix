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
      # scripts/setup.sh が local.nix.example を雛形に生成する。
      #
      # local.nix は .gitignore 済み。just / setup.sh は flake を path: 指定で参照
      # するため、git 追跡の有無に関係なくその場の local.nix が読まれる (`git add -f`
      # のような小細工は不要)。逆に `.#...` (path: 無し) で git 経由に評価すると、
      # git リポジトリでは追跡外の local.nix が見えずここに落ちる。
      local =
        if builtins.pathExists ./local.nix then
          import ./local.nix
        else
          throw ''
            local.nix がありません。

            初回セットアップなら scripts/setup.sh を実行してください:
              ~/dotfiles/scripts/setup.sh

            既にあるのにこのエラーが出る場合、flake を git 経由 (.#...) で評価して
            います。path: を付けて参照してください (just は既にそうしています):
              nix build path:~/dotfiles#homeConfigurations.$(id -un).activationPackage
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
