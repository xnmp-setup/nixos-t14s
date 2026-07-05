# nixos-t14s

NixOS + Hyprland for a **ThinkPad T14s Gen 3 AMD** (Ryzen 7 PRO 6850U, Radeon 680M,
32GB, 512GB NVMe). A lean, portable terminal + AI-coding box.

**Split of responsibility:** NixOS installs **packages + system config**; your existing
**chezmoi** repo lays down all **dotfiles** (Hyprland, WezTerm, zsh/p10k, scratchpad
scripts). No Home Manager — configs stay in chezmoi so this box matches your desktop
(and Mac) with one source of truth.

```
flake.nix                     inputs + the `t14s` nixosConfiguration (packages-only)
hosts/t14s/
  default.nix                 host: hostname, stateVersion, module imports
  hardware-configuration.nix  PLACEHOLDER — regenerate on the laptop (see below)
modules/
  system.nix                  boot, network, audio, TLP battery, syncthing, greetd, fonts
  hyprland.nix                Hyprland+hyprlock, amdgpu/mesa, portals, waybar/wofi/hyprpaper/hyprshot, thunar
  dev.nix                     terminals, editors, CLI, node/uv/go/rust(+mold/sccache)
```

## What's installed (reflected from your desktop)

- **Terminals:** wezterm, ghostty, kitty
- **Editors:** zed, lite-xl, obsidian, micro *(vscode left off the lean box — commented)*
- **Shell/CLI:** zsh, fish, atuin, zoxide, fzf, ripgrep, fd, bat, eza, jq, yazi, zellij, tmux, gh, gh-dash, lazygit
- **Langs:** node, uv (Python), go, rustup + mold + sccache
- **Desktop:** Hyprland, hyprlock, hyprpaper, hyprshot, waybar, wofi, gammastep, imv, thunar
- **Other:** google-chrome, rclone, syncthing (service), chezmoi

**Not installed via nix (bring your own way):**
- **Claude Code** — native self-updating installer: `curl -fsSL https://claude.ai/install.sh | bash`
- **vicinae** (launcher) and **lpm** (Lite XL plugin mgr) — not in nixpkgs; install via your own method
- **rtk**, **bd/beads**, **ccstatusline** — your custom tools, via chezmoi / their own installers

## Install on the laptop (day it arrives)

1. **Acceptance test first** (no returns — do this before wiping Windows). Boot the NixOS
   installer USB and confirm you got what you paid for:
   ```bash
   lscpu | grep -E 'Model name|^CPU\(s\)'      # Ryzen 7 PRO 6850U, 16 threads
   free -h                                      # ~31Gi
   lsblk -d -o NAME,SIZE,MODEL                   # ~476G NVMe
   lspci | grep -iE 'vga|display'                # Radeon 680M (Rembrandt)
   cat /sys/class/power_supply/BAT0/charge_full{,_design}   # battery health = full ÷ design
   ```

2. **Partition + mount** (UEFI: an ESP + a root), then generate the real hardware config:
   ```bash
   sudo nixos-generate-config --root /mnt
   ```

3. **Drop this repo in and swap the hardware file:**
   ```bash
   git clone <your-repo> /mnt/home/chong/Repos/nixos-t14s
   cp /mnt/etc/nixos/hardware-configuration.nix \
      /mnt/home/chong/Repos/nixos-t14s/hosts/t14s/hardware-configuration.nix
   ```

4. **Install, then reboot:**
   ```bash
   sudo nixos-install --flake /mnt/home/chong/Repos/nixos-t14s#t14s
   ```

5. **After first boot — lay down your world:**
   ```bash
   chezmoi init --apply <your-dotfiles-repo>      # Hyprland, wezterm, zsh/p10k, scripts
   curl -fsSL https://claude.ai/install.sh | bash # Claude Code (native)
   sudo nixos-rebuild switch --flake ~/Repos/nixos-t14s#t14s   # iterate from here
   ```

## Notes

- **stateVersion**: set `system.stateVersion` to whatever `nixos-version` shows at
  install, then never change it.
- **Rust build speed**: `sccache` is wired globally. Enable **mold** per-project via
  `<project>/.cargo/config.toml`:
  ```toml
  [target.x86_64-unknown-linux-gnu]
  linker = "clang"
  rustflags = ["-C", "link-arg=-fuse-ld=mold"]
  ```
  For heavier crates, prefer a per-project `nix develop` devshell over global tools.
- **Battery**: charge capped 40–80% to nurse a used cell; raise `STOP_CHARGE_THRESH_BAT0`
  to 100 the night before a long day out.
- **Notifications**: no daemon was installed on your desktop — add `mako` (in
  `modules/hyprland.nix`) if you want them, and configure via chezmoi.
