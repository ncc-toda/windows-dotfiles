# Convenience wrapper around home-manager. Run `just` for the common flow,
# or `just <recipe>`. `just --list` shows everything.
#
# 設定名はユーザー名 (flake.nix が local.nix の username で登録する) なので、
# 誰の環境でも同じレシピがそのまま動く。ハードコードしない。
#
# flake 参照は path: 指定にしてある。これにより「git 管理外の local.nix」を
# 追跡状態に関係なく読める (git add -f が不要)。学生の ~/dotfiles は非 git
# ディレクトリ、開発者のは git リポジトリだが、path: ならどちらでも同じに動く。

repo := "path:" + env_var('HOME') + "/dotfiles"

# Apply the configuration (default). First run backs up any pre-existing dotfiles.
switch:
    home-manager switch --flake {{repo}}#$(id -un) -b backup

# Build without activating, to check that everything evaluates/compiles.
build:
    nix build {{repo}}#homeConfigurations.$(id -un).activationPackage --no-link

# Update all flake inputs (nixpkgs, home-manager) to their latest, then apply.
update:
    nix flake update --flake {{repo}}
    just switch

# Fetch the latest dotfiles content itself (not just inputs) and re-apply.
# 学生向け: dotfiles の中身の更新は git pull ではなく tarball 取り直しで行う。
# 取得先は配布ブランチ 'release' (= 動作確認済みの最新)。開発版やタグを試すなら
# `just upgrade main` / `just upgrade v1.2` のように ref を渡す (archive/<ref> の
# 短縮形はブランチ/タグ/コミットのいずれでも効く)。
upgrade ref='release':
    curl -fsSL https://github.com/ncc-toda/windows-dotfiles/archive/{{ref}}.tar.gz \
        | tar xz --strip-components=1 -C ~/dotfiles
    just switch

# Show what generations exist / roll back if something breaks.
generations:
    home-manager generations
