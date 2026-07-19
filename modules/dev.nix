{ pkgs, ... }:
{
  # Loader shim for generic-Linux dynamic binaries (Claude Code's native
  # installer, downloaded AppImages/tools). Without it NixOS refuses them with
  # "Could not start dynamically linked executable".
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    # --- Terminals (all three you use; WezTerm is primary) ---
    wezterm ghostty kitty

    # --- Editors (your lean set: Zed, Lite XL, Obsidian, micro) ---
    zed-editor
    lite-xl        # NOTE: `lpm` (Lite plugin manager) isn't in nixpkgs — install via chezmoi/npm
    obsidian
    micro
    # vscode      # you have it, left out of the lean box — uncomment if you want it

    # --- CLI / shell tooling ---
    zsh fish atuin        # shells + history sync (configs via chezmoi/p10k)
    zoxide fzf ripgrep fd bat eza jq yazi
    zellij tmux
    gh gh-dash lazygit
    # Present on the desktop and previously missed here:
    dust ncdu             # disk usage
    csvlens tidy-viewer   # CSV viewing in the terminal
    handlr-regex          # xdg-open replacement / default-app routing
    shfmt
    less unzip whois socat ffmpeg
    xclip xsel wtype      # clipboard + synthetic input (wl-clipboard is in hyprland.nix)

    # --- Languages / build ---
    nodejs_22
    uv            # your Python toolchain
    go
    rustup        # Rust; toolchains installed on demand
    mold          # fast linker — biggest single win on Rust link time (see README)
    sccache       # shared compiler cache across projects
    pkg-config openssl gcc gnumake

    # --- Sync / cloud (syncthing runs as a service in system.nix) ---
    rclone

    # --- Browser ---
    google-chrome
    # vivaldi is installed on the desktop (and chezmoi carries .config/vivaldi +
    # vivaldi-mods/) but is deliberately NOT on the lean laptop.

    # --- Tauri toolchain ---
    # You maintain github.com/xnmp/tauri-explorer, which is NOT in nixpkgs (see README).
    # These are what it needs to build from source on this machine.
    cargo-tauri
    webkitgtk_4_1
  ];

  # Cache Rust builds globally; enable the mold linker per-project (README) so it
  # never surprises a build expecting the default linker.
  #
  # Absolute store path, not the bare name: this var is exported for every user and
  # every context, including `nix develop` shells, systemd units and containers where
  # `sccache` is not on PATH. With a bare "sccache" those builds fail hard rather than
  # degrading to an uncached build.
  environment.variables = {
    RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
  };

  # Containers: you use docker here, but it's left off the lean box. To enable:
  #   virtualisation.docker.enable = true;   (and add "docker" to your user's groups)

  # Claude Code: NOT installed via nix — you use the self-updating native installer.
  # On first boot:  curl -fsSL https://claude.ai/install.sh | bash
  # (ccstatusline + your rtk / bd tools also come via your own install + chezmoi.)
}
