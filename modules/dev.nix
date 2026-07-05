{ pkgs, ... }:
{
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
  ];

  # Cache Rust builds globally; enable the mold linker per-project (README) so it
  # never surprises a build expecting the default linker.
  environment.variables = {
    RUSTC_WRAPPER = "sccache";
  };

  # Containers: you use docker here, but it's left off the lean box. To enable:
  #   virtualisation.docker.enable = true;   (and add "docker" to your user's groups)

  # Claude Code: NOT installed via nix — you use the self-updating native installer.
  # On first boot:  curl -fsSL https://claude.ai/install.sh | bash
  # (ccstatusline + your rtk / bd tools also come via your own install + chezmoi.)
}
