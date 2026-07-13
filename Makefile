# Convenience wrapper around home-manager. Run `make` for the common flow.
HM_FLAKE := $(HOME)/dotfiles#tetsuo

.DEFAULT_GOAL := switch

# Apply the configuration. First run backs up any pre-existing dotfiles.
switch:
	home-manager switch --flake $(HM_FLAKE) -b backup

# Build without activating, to check that everything evaluates/compiles.
build:
	nix build $(HOME)/dotfiles#homeConfigurations.tetsuo.activationPackage --no-link

# Update all flake inputs (nixpkgs, home-manager) to their latest.
update:
	cd $(HOME)/dotfiles && nix flake update

# Show what generations exist / roll back if something breaks.
generations:
	home-manager generations

.PHONY: switch build update generations
