# Convenience wrapper around home-manager. Run `just` for the common flow,
# or `just <recipe>`. `just --list` shows everything.

flake       := "~/dotfiles#tetsuo"
build_target := "~/dotfiles#homeConfigurations.tetsuo.activationPackage"

# Apply the configuration (default). First run backs up any pre-existing dotfiles.
switch:
    home-manager switch --flake {{flake}} -b backup

# Build without activating, to check that everything evaluates/compiles.
build:
    nix build {{build_target}} --no-link

# Update all flake inputs (nixpkgs, home-manager) to their latest, then apply.
update:
    cd ~/dotfiles && nix flake update
    just switch

# Show what generations exist / roll back if something breaks.
generations:
    home-manager generations
