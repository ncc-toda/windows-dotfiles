{ ... }:
{
  # ---------------------------------------------------------------------------
  # Claude Code の user-level skill を配布する。
  #
  # `claude` バイナリ本体は scripts/setup.sh が公式インストーラで導入する。ここで
  # 配るのは「この dotfiles を自分のベースにする」ための手順書 = skill で、学生の
  # ~/.claude/skills/<name>/ 以下へ置く。学生が claude を起動して opt-in で呼ぶ。
  #
  # ポイント: skills ディレクトリ "そのもの" ではなく、各 skill サブディレクトリ単位で
  # symlink する。こうすると ~/.claude/skills/ 自体は普通のディレクトリのままなので、
  # 学生が自分の skill を隣に足せる (ディレクトリごと symlink にすると読取専用になり
  # 追加できなくなる)。中身は配布物なので編集させない前提 (編集したい人は fork する)。
  # ---------------------------------------------------------------------------
  home.file.".claude/skills/adopt-this-setup".source = ../claude/skills/adopt-this-setup;
}
