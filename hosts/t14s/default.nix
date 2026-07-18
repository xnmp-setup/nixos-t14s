{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system.nix
    ../../modules/hyprland.nix
    ../../modules/dev.nix
  ];

  networking.hostName = "t14s";

  # Pins stateful defaults, not package versions. Set once, then never change it.
  # NOTE: the pinned nixpkgs actually builds 26.11, so `nixos-version` will report
  # 26.11, not this. That's fine and deliberate — older is the conservative
  # direction for stateVersion. Do not "correct" it to match after installing.
  system.stateVersion = "25.11";
}
