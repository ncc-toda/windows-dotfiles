{ ... }:
{
  programs.git = {
    enable = true;

    # New freeform schema: `settings` mirrors git config sections directly.
    settings = {
      user.name = "ncc-toda";
      user.email = "oda.tetsuo@nsg.gr.jp";

      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      fetch.prune = true;
      diff.colorMoved = "default";
      merge.conflictStyle = "zdiff3";

      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        last = "log -1 HEAD";
        lg = "log --oneline --graph --decorate --all -30";
      };
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv/"
      "result"
      "result-*"
    ];
  };

  # delta: syntax-highlighted, side-by-side-capable git diffs.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
    };
  };
}
