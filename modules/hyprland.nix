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

  # hyprland.conf runs `gnome-keyring-daemon --start --components=secrets`;
  # the module ships the package and wires up PAM unlock-on-login.
  services.gnome.gnome-keyring.enable = true;

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
    # Screenshots: hyprshot only. hyprland.conf:130 binds
    #   $mainMod SHIFT, S -> hyprshot -m region --clipboard-only
    # and the nixpkgs wrapper already carries grim, slurp, wl-clipboard, jq and
    # libnotify, so that keybind works with nothing else installed. flameshot is on
    # the desktop but unused, and is deliberately not carried over.
    hyprpaper     # wallpaper (you use this, not swww)
    hyprshot      # screenshots (you use this, not grim/slurp)
    wl-clipboard
    brightnessctl playerctl
    wlsunset      # night-light — what hyprland.conf actually launches
    gammastep     # kept: the conf has a commented gammastep fallback line
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
