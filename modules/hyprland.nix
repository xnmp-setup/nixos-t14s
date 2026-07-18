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
  services.gvfs.enable = true;  # without this Thunar cannot mount USB drives or use trash
  services.tumbler.enable = true; # thumbnails

  # Your Wayland toolkit — reflects what's installed on your desktop.
  environment.systemPackages = with pkgs; [
    waybar
    wofi          # fallback launcher
    vicinae       # your actual launcher — it IS in nixpkgs now; the README's
                  # "not packaged, bring your own" note was stale.
    flameshot     # you have this alongside hyprshot on the desktop
    nwg-look      # GTK theme/font settings for a Wayland session
    gnome-themes-extra
    seahorse      # GUI for the gnome-keyring secrets your apps store
    libayatana-appindicator # tray icons for Electron/GTK apps (YT Music, Docker, etc.)
    hyprpaper     # wallpaper (you use this, not swww)
    hyprshot      # screenshots (you use this, not grim/slurp)
    wl-clipboard
    brightnessctl playerctl
    gammastep     # night-light / colour temperature
    imv           # image viewer
    # polkit authentication agent. security.polkit is only the daemon; Hyprland
    # starts no agent of its own, so without this every GUI privilege prompt
    # (Thunar mounting a drive, fwupd, NetworkManager) fails silently.
    # Needs `exec-once = systemctl --user start hyprpolkitagent` in your chezmoi hypr config.
    hyprpolkitagent
    # No notification daemon was installed on your desktop — add one if you want,
    # e.g. `mako` or `swaynotificationcenter`, then configure it via chezmoi:
    # mako
  ];
}
