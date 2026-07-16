{ local, lib, ... }:
let
  # git の身元は任意。local.nix に git.name/email が両方あり、かつ空でない
  # ときだけ user.* を設定する。無い/空なら未設定のまま (環境は動く。commit
  # する時に git が名前を聞いてくるだけ)。
  g = local.git or { };
  hasIdentity = (g.name or "") != "" && (g.email or "") != "";
in
{
  programs.git = {
    enable = true;

    # New freeform schema: `settings` mirrors git config sections directly.
    # 最小構成: 身元 (任意) と、無害で安全側の既定だけ。alias / delta は入れない。
    settings = lib.mkMerge [ (lib.mkIf hasIdentity {
      # 身元は local.nix から (マシン/人ごとに違うのでここに直接書かない)。
      user.name = g.name;
      user.email = g.email;
    }) {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      fetch.prune = true;
    } ];

    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv/"
      "result"
      "result-*"
    ];
  };
}
