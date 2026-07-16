# Convenience wrapper around home-manager. Run `just` for the common flow,
# or `just <recipe>`. `just --list` shows everything.
#
# 設定名はユーザー名 (flake.nix が local.nix の username で登録する) なので、
# 誰の環境でも同じレシピがそのまま動く。ハードコードしない。

repo := "~/dotfiles"

# Apply the configuration (default). First run backs up any pre-existing dotfiles.
switch:
    home-manager switch --flake {{repo}}#$(id -un) -b backup

# Build without activating, to check that everything evaluates/compiles.
build:
    nix build {{repo}}#homeConfigurations.$(id -un).activationPackage --no-link

# Update all flake inputs (nixpkgs, home-manager) to their latest, then apply.
update:
    cd {{repo}} && nix flake update
    just switch

# Show what generations exist / roll back if something breaks.
generations:
    home-manager generations
