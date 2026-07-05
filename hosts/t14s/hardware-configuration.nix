# ┌─────────────────────────────────────────────────────────────────────────┐
# │ PLACEHOLDER — REPLACE THIS FILE ON THE LAPTOP AT INSTALL TIME.             │
# │                                                                           │
# │ Boot the NixOS installer, partition+mount your disk, then run:            │
# │     sudo nixos-generate-config --root /mnt                                 │
# │ and copy /mnt/etc/nixos/hardware-configuration.nix OVER this file.         │
# │ It auto-detects your real NVMe device, filesystems, and kernel modules.   │
# │                                                                           │
# │ The stub below only lets the flake *evaluate* on another machine so you   │
# │ can review it before install. It is NOT bootable as-is.                   │
# └─────────────────────────────────────────────────────────────────────────┘
{ lib, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # These are fake and will be overwritten by nixos-generate-config:
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };
}
