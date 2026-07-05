{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system.nix
    ../../modules/hyprland.nix
    ../../modules/dev.nix
  ];

  networking.hostName = "t14s";

  # Set this to the release you FIRST install (see `nixos-version`) and then
  # never change it — it pins stateful defaults, not your package versions.
  system.stateVersion = "25.11";
}
