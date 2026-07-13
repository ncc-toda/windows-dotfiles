{ ... }:
{
  programs.git = {
    enable = true;

    # TODO: set these to your own identity.
    userName = "tetsuo";
    userEmail = "ncc.system.ai@gmail.com";

    # delta: syntax-highlighted, side-by-side-capable diffs.
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
      };
    };

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      fetch.prune = true;
      diff.colorMoved = "default";
      merge.conflictStyle = "zdiff3";
    };

    aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
      last = "log -1 HEAD";
      lg = "log --oneline --graph --decorate --all -30";
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv/"
      "result"
      "result-*"
    ];
  };
}
