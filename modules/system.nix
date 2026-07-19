{ pkgs, ... }:
{
  # --- Boot ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Deliberately the nixpkgs default kernel, NOT linuxPackages_latest. Rembrandt
  # (Radeon 680M) has been fully supported since ~5.17, so tracking mainline buys
  # nothing here and costs out-of-tree module breakage on a laptop with no fallback OS.
  # boot.kernelPackages = pkgs.linuxPackages_6_18; # pin explicitly if you ever need to

  # Panel Self Refresh on this model causes flicker, corruption, and post-suspend
  # `flip_done timed out` freezes. Still open upstream (drm/amd#2735). Drop this
  # param and rebuild if a future kernel fixes it — it costs a little idle power.
  boot.kernelParams = [ "amdgpu.dcdebugmask=0x10" ];

  # Wi-Fi/GPU/Bluetooth firmware + AMD microcode. The generated hardware-configuration.nix
  # normally brings this in via not-detected.nix, but it is far too important to inherit
  # implicitly: without it there is no Wi-Fi on first boot, and no Ethernet port to fall
  # back on.
  hardware.enableRedistributableFirmware = true;

  # 8GB swapfile. Declared here rather than created by hand at install time, because
  # `nixos-generate-config` deliberately ignores swap *files* and would silently leave
  # the system with no swap at all. NixOS creates the file on activation.
  swapDevices = [ { device = "/.swapfile"; size = 8192; } ];

  services.fstrim.enable = true; # NVMe longevity

  # --- Networking ---
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  # --- Locale / time (adjust to where you actually are) ---
  time.timeZone = "Australia/Sydney";
  i18n.defaultLocale = "en_AU.UTF-8";
  console.keyMap = "us";

  # --- Audio (PipeWire) ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # --- Battery & thermals: matters for working away from a wall socket ---
  # Required: since TLP 1.6.0, TLP silently skips BOTH the platform-profile and
  # charge-threshold settings below if power-profiles-daemon is running.
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      # On AMD the platform profile IS the power-management path — setting
      # CPU_ENERGY_PERF_POLICY_* alongside it means the two stomp on each other
      # (see TLP's ppd FAQ). Platform profile only, deliberately.
      PLATFORM_PROFILE_ON_BAT = "low-power";
      PLATFORM_PROFILE_ON_AC = "performance";
      # Protect a used battery: only charge 40%->80% for daily desk use.
      # For a long day out run `sudo tlp fullcharge` — one-shot, no rebuild, and
      # TLP restores these thresholds by itself on the next unplug. Do NOT "just set
      # STOP to 100": on ThinkPads that *disables* the threshold rather than
      # setting a 100% target.
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # Spurious wakeups from the touchpad drain the battery in a closed bag.
  services.udev.extraRules = ''
    KERNEL=="i2c-SYNA8018:00", SUBSYSTEM=="i2c", ATTR{power/wakeup}="disabled"
  '';

  services.fwupd.enable = true; # ThinkPad firmware updates from Linux

  # SSH in from the desktop, key-only. Note the TP-Link router blocks wired->wireless
  # traffic (AP isolation), so the desktop cannot connect directly; from the laptop run
  #   ssh -R 2222:localhost:22 chong@<desktop-ip>
  # and the desktop then reaches this machine via `ssh -p 2222 chong@localhost`.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Auto-renice/ionice processes by rules, same as the Arch desktop's ananicy-cpp.
  # The CachyOS ruleset is the maintained rules companion for ananicy-cpp.
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  # Fingerprint reader (T14s has one) — uncomment to enable:
  # services.fprintd.enable = true;

  # --- File sync between this laptop and your desktop ---
  services.syncthing = {
    enable = true;
    user = "chong";
    openDefaultPorts = true;
    overrideDevices = false; # keep the devices/folders you set up in the UI
    overrideFolders = false;
  };

  # --- Login: greetd + tuigreet launches Hyprland straight into your session ---
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      user = "greeter";
    };
  };

  # --- User ---
  users.users.chong = {
    isNormalUser = true;
    description = "chong";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ]; # add "docker" if you enable it
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAX2u1QV0nRFAohKc9dP/PgrM2wjfUY4Cshz7Ba/ds7K chong@desktop"
    ];
  };
  programs.zsh.enable = true; # install + login shell; your .zshrc/p10k come from chezmoi

  # --- Fonts (your actual coding font + icon glyphs) ---
  fonts.packages = with pkgs; [
    commit-mono
    nerd-fonts.symbols-only # icon glyphs for waybar/prompt
    # The rest of the desktop's font set — without these, anything in your chezmoi
    # configs that names a font you don't have here silently falls back.
    cascadia-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.victor-mono
    nerd-fonts.fantasque-sans-mono
    inter                   # UI font
    ubuntu-classic          # renamed from ubuntu_font_family in nixpkgs
    font-awesome            # waybar/wofi icon sets
  ];

  # --- Nix ---
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true; # obsidian, google-chrome, etc.

  # Base: chezmoi first so you can lay down all your dotfiles on first boot.
  environment.systemPackages = with pkgs; [ chezmoi git vim wget curl ];
}
