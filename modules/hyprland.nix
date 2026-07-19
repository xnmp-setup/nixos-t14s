{ pkgs, ... }:
let
  # Not in nixpkgs — built from source, see pkgs/pam_pwdfile.nix for provenance.
  pam_pwdfile = pkgs.callPackage ../pkgs/pam_pwdfile.nix { };
in
{
  # Hyprland session + portals. Your actual hypr config (keybinds, scratchpad
  # scripts, session save/restore) comes from chezmoi — this just provides the
  # compositor and the tools it calls.
  programs.hyprland.enable = true;
  programs.hyprlock.enable = true; # you use hyprlock; the module wires up PAM

  # Unlock hyprlock with a short PIN instead of the full account password.
  #
  # order 11500 places this ahead of pam_unix (11700) and `sufficient` means a
  # matching PIN unlocks immediately, while a non-match falls through to the
  # normal password — so a missing or malformed /etc/pinfile degrades to the
  # password prompt and cannot lock you out.
  #
  # Scoped to hyprlock ONLY. It is deliberately not added to login, sudo, or
  # sshd: the PIN is a weaker secret and must not become a path to root or to a
  # remote shell.
  #
  # /etc/pinfile is intentionally NOT declared in Nix — environment.etc copies
  # file contents into the world-readable /nix/store. Create it out of band:
  #   printf 'chong:%s\n' "$(mkpasswd -m sha-512)" | sudo tee /etc/pinfile
  #   sudo chown chong:users /etc/pinfile && sudo chmod 400 /etc/pinfile
  #
  # Ownership is chong, NOT root, and this is load-bearing. hyprlock is not
  # setuid — it runs as uid 1000 — so pam_pwdfile open()s this file as chong.
  # Root-owned 0600 yields "couldn't open password file" in the journal and a
  # silent fallthrough to the password prompt. (pam_unix survives the same
  # situation only because it shells out to the setuid unix_chkpwd helper to
  # read /etc/shadow; pam_pwdfile has no equivalent.)
  #
  # Consequence, accepted deliberately: the PIN hash is readable by your own
  # uid, so anything running as chong can brute-force a short PIN offline. That
  # is unavoidable for an unprivileged lock screen reading a flat file. It still
  # holds against the actual threat here — someone at the keyboard of a locked
  # session — but it is strictly weaker than pam_unix, which is why this is
  # confined to hyprlock.
  security.pam.services.hyprlock.rules.auth.pwdfile = {
    order = 11500;
    control = "sufficient";
    modulePath = "${pam_pwdfile}/lib/security/pam_pwdfile.so";
    # pwdfile= is the only argument wanted. sha-512 hashes are handled by the
    # system crypt_r by default (bigcrypt and broken-md5 are the only formats
    # upstream disables). Note the module also accepts `nodelay`, which removes
    # PAM's delay on auth failure — deliberately NOT set, since that delay is
    # the main thing slowing brute-force against a secret this short.
    args = [ "pwdfile=/etc/pinfile" ];
  };

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

    # Without an XCURSOR theme on XCURSOR_PATH, Hyprland falls back to its own
    # compiled-in cursor — the blue teardrop — rather than to anything resembling
    # a normal pointer. Nothing was installed, so that fallback was all there was.
    # adwaita-icon-theme (below) puts Adwaita on the path; this selects it.
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
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
    # Cursor theme. Provides share/icons/Adwaita/cursors, picked up via
    # XCURSOR_PATH (which already covers /run/current-system/sw/share/icons).
    # Selected by XCURSOR_THEME above — installing alone is not enough.
    adwaita-icon-theme
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
    # F7 scratchpad app (same 2.0.11 as the desktop's ytmdesktop-bin). The wrapper
    # matches Arch's binary name, which the hyprland.conf bind invokes.
    ytmdesktop
    (writeShellScriptBin "youtube-music-desktop-app" ''exec ${ytmdesktop}/bin/ytmdesktop "$@"'')
    # No notification daemon was installed on your desktop — add one if you want,
    # e.g. `mako` or `swaynotificationcenter`, then configure it via chezmoi:
    # mako
  ];
}
