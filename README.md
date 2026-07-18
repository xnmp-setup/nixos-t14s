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

Reconciled against `pacman -Qe` on the Arch desktop, so this list is measured, not remembered.

- **Terminals:** wezterm, ghostty, kitty
- **Editors:** zed, lite-xl, obsidian, micro *(vscode left off the lean box — commented)*
- **Browsers:** google-chrome, vivaldi
- **Shell/CLI:** zsh, fish, atuin, zoxide, fzf, ripgrep, fd, bat, eza, jq, yazi, zellij, tmux,
  gh, gh-dash, lazygit, dust, ncdu, csvlens, tidy-viewer, handlr-regex, shfmt, less, unzip,
  whois, socat, ffmpeg, xclip/xsel/wtype
- **Langs:** node, uv (Python), go, rustup + mold + sccache, cargo-tauri + webkitgtk_4_1
- **Desktop:** Hyprland, hyprlock, hyprpaper, hyprshot, waybar, wofi, vicinae, flameshot,
  gammastep, imv, thunar, nwg-look, seahorse, hyprpolkitagent
- **Other:** rclone, syncthing (service), chezmoi

**Deliberately NOT carried over from the desktop:** nvidia-*, qemu/libvirt/virt-manager,
docker-desktop, vagrant, grub/os-prober, nvm. Desktop-only or wrong for an AMD laptop
booting systemd-boot.

**Not installed via nix (bring your own way):**
- **Claude Code** — native self-updating installer: `curl -fsSL https://claude.ai/install.sh | bash`
- **tauri-explorer** — your own project (github.com/xnmp/tauri-explorer), not in nixpkgs.
  Build from source; `cargo-tauri` + `webkitgtk_4_1` are installed for exactly this.
- **lpm** (Lite XL plugin mgr) — genuinely not in nixpkgs.
- **rtk**, **bd/beads**, **ccstatusline** — your custom tools, via chezmoi / their own installers

*(`vicinae` used to be listed here as unpackaged. It is in nixpkgs now and is installed.)*

## Where each app's settings come from

NixOS installs binaries; it does not carry settings. Three different mechanisms do:

| Source | Apps |
|---|---|
| **chezmoi** | wezterm, ghostty, hypr, yazi, zellij, lite-xl, micro, zed, imv, vivaldi, VS Code, zsh/p10k, gitconfig, ccstatusline, `.local/bin`, scripts |
| **Syncthing** | **Obsidian** — settings live in `~/Vaults/*/.obsidian`, inside the vault, so they ride the vault sync rather than chezmoi |
| **nothing yet** | kitty, fish, atuin, gh, gh-dash, lazygit, rclone, uv, gammastep, vicinae — these have config on the desktop that chezmoi does **not** track, so they will arrive at defaults |

That last row is the real gap: those settings exist on the desktop but nothing carries them.
Add them to chezmoi before the migration if you care about them. waybar, wofi, hyprpaper and
hyprshot have no config on the desktop either, so they are already at parity (bare on both).

## Install on the laptop

**See [INSTALL.md](INSTALL.md)** — the full walkthrough: wipe Windows, LUKS + ext4,
firmware and BIOS prep, recovery paths, and T14s-specific troubleshooting.

An abbreviated copy of those steps used to live here and had drifted out of sync (no
LUKS, a battery command that errors on this model, and it omitted committing the
generated hardware config). One source of truth instead.

Sanity-check the config on another x86_64 Linux box before install day:

```bash
nix build --no-link .#nixosConfigurations.t14s.config.system.build.toplevel
nixos-rebuild build-vm --flake .#t14s && ./result/bin/run-t14s-vm   # watch it actually boot
```

## Notes

- **stateVersion**: `25.11`, deliberately. The pinned nixpkgs builds 26.11, so
  `nixos-version` will disagree — that is fine and intended. Older is the conservative
  direction. Set once, never "correct" it.
- **Rust build speed**: `sccache` is wired globally. Enable **mold** per-project via
  `<project>/.cargo/config.toml`:
  ```toml
  [target.x86_64-unknown-linux-gnu]
  linker = "clang"
  rustflags = ["-C", "link-arg=-fuse-ld=mold"]
  ```
  For heavier crates, prefer a per-project `nix develop` devshell over global tools.
- **Battery**: charge capped 40–80% to nurse a used cell. For a long day out run
  `sudo tlp fullcharge` — one-shot, no rebuild, thresholds restore themselves on the next
  unplug. Do **not** set `STOP_CHARGE_THRESH_BAT0 = 100`: on ThinkPads that *disables* the
  threshold rather than targeting 100%.
- **Notifications**: no daemon was installed on your desktop — add `mako` (in
  `modules/hyprland.nix`) if you want them, and configure via chezmoi.
