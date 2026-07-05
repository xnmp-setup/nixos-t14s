{ pkgs, ... }:
{
  # --- Boot ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest; # fresh kernel = happiest amdgpu

  # --- Networking ---
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  # --- Locale / time (adjust to where you actually are) ---
  time.timeZone = "Australia/Perth";
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
  services.power-profiles-daemon.enable = false; # conflicts with TLP
  services.tlp = {
    enable = true;
    settings = {
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      PLATFORM_PROFILE_ON_AC = "performance";
      # Protect a used battery: only charge 40%->80% for daily desk use.
      # Bump STOP to 100 the night before a long day out.
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  services.fwupd.enable = true; # ThinkPad firmware updates from Linux

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
  };
  programs.zsh.enable = true; # install + login shell; your .zshrc/p10k come from chezmoi

  # --- Fonts (your actual coding font + icon glyphs) ---
  fonts.packages = with pkgs; [
    commit-mono
    nerd-fonts.symbols-only # icon glyphs for waybar/prompt
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
