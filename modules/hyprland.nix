{ pkgs, ... }:
{
  # Hyprland session + portals. Your actual hypr config (keybinds, scratchpad
  # scripts, session save/restore) comes from chezmoi — this just provides the
  # compositor and the tools it calls.
  programs.hyprland.enable = true;
  programs.hyprlock.enable = true; # you use hyprlock; the module wires up PAM

  # GPU / Wayland acceleration for the Radeon 680M (amdgpu + RADV via mesa).
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-utils # `vainfo` to confirm HW video decode (mesa/radeonsi provides the driver)
    ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron/Chromium (Claude Code env, Chrome) on native Wayland
    MOZ_ENABLE_WAYLAND = "1";
  };

  # File manager (matches your Thunar + plugins setup here).
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [ thunar-archive-plugin thunar-volman ];
  };

  # Your Wayland toolkit — reflects what's installed on your desktop.
  environment.systemPackages = with pkgs; [
    waybar
    wofi          # launcher (NOTE: vicinae isn't in nixpkgs — bring it via your own install)
    hyprpaper     # wallpaper (you use this, not swww)
    hyprshot      # screenshots (you use this, not grim/slurp)
    wl-clipboard
    brightnessctl playerctl
    gammastep     # night-light / colour temperature
    imv           # image viewer
    # No notification daemon was installed on your desktop — add one if you want,
    # e.g. `mako` or `swaynotificationcenter`, then configure it via chezmoi:
    # mako
  ];
}
