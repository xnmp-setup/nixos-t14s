{
  description = "NixOS + Hyprland for ThinkPad T14s Gen 3 AMD — mobile WezTerm + Claude Code box";

  # Packages + system only. Dotfiles are managed by chezmoi (Hyprland, WezTerm,
  # zsh/p10k, scratchpad scripts, etc.), so there is deliberately no Home Manager here.
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.t14s = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          # Hardware (guaranteed-to-exist building blocks). If nixos-hardware gains a
          # `lenovo-thinkpad-t14s-amd-gen3` profile, prefer it — check `nix flake show`.
          nixos-hardware.nixosModules.common-cpu-amd
          nixos-hardware.nixosModules.common-cpu-amd-pstate
          nixos-hardware.nixosModules.common-gpu-amd
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-laptop-ssd

          ./hosts/t14s
        ];
      };
    };
}
