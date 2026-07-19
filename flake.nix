{
  description = "NixOS + Hyprland for ThinkPad T14s Gen 3 AMD — mobile WezTerm + Claude Code box";

  # Packages + system only. Dotfiles are managed by chezmoi (Hyprland, WezTerm,
  # zsh/p10k, scratchpad scripts, etc.), so there is deliberately no Home Manager here.
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    # Without this, nixos-hardware drags in a SECOND full nixpkgs — a needless
    # multi-hundred-MB fetch over Wi-Fi during the install.
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # Your own file manager, built from its flake (packages.default).
    # follows = same nixpkgs as the system: one evaluation, one webkitgtk.
    tauri-explorer.url = "github:xnmp/tauri-explorer";
    tauri-explorer.inputs.nixpkgs.follows = "nixpkgs";

    # Your keifu fork (git-graph TUI) — development happens on chong-dev.
    keifu.url = "github:xnmp/keifu/chong-dev";
    keifu.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.t14s = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          # There is no `-amd-gen3` profile for the T14s. The generic one is the right
          # pick: it only adds `acpi_backlight=native` (its linuxPackages_latest line is
          # a dead `versionOlder "5.2"` guard).
          # Do NOT substitute `lenovo-thinkpad-t14s-amd-gen1` — it forces
          # `mem_sleep_default=deep`, and this CPU generation is s2idle-only. Setting
          # deep sleep here crashes on suspend.
          nixos-hardware.nixosModules.lenovo-thinkpad-t14s

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
