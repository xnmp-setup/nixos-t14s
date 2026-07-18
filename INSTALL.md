# Installing on the T14s (wipe Windows, LUKS + ext4)

Target: ThinkPad T14s Gen 3 AMD, 512GB NVMe. This **erases the whole disk**, including
Windows. Back up anything on it first — there is no undo after step 5.

Layout produced:

```
/dev/nvme0n1p1   1GB    FAT32, ESP           -> /boot   (unencrypted, required)
/dev/nvme0n1p2   rest   LUKS2 -> ext4        -> /       (encrypted)
```

Swap is an 8GB file declared in `modules/system.nix` and created by NixOS on activation —
**do not create it by hand.** `nixos-generate-config` deliberately ignores swap *files*
(`nixos-generate-config.pl`: *"swap files are more likely specified in configuration.nix,
so ignore them here"*), so a hand-made one is never written into the config and the
installed system silently boots with no swap.

---

## 0. Before you leave Windows

- Copy off anything you want to keep.
- Note your Wi-Fi SSID + password. **The T14s Gen 3 AMD has no Ethernet port**, so the
  installer needs Wi-Fi. (Gen 1 and Gen 2 had a mini-RJ45 extension connector — inherited
  docs will mislead you here.)
- **Update the BIOS from Windows now, via Lenovo Vantage.** Easiest while Windows is still
  there, and it dodges a known-bad firmware — see step 2. Note the version you land on:
  from **0.1.49** onward, AMD Secure Processor rollback protection makes downgrading
  **permanently impossible**, even with Secure Rollback Prevention turned off. One-way door.

## 1. Make the USB

Download from <https://nixos.org/download/#nixos-iso>. **Either ISO works** — since 25.11
both the minimal and GNOME images ship NetworkManager (`nmtui`, `nmcli`) and git. Take
GNOME if you want a browser and GParted on hand while installing; minimal is smaller and
fine. (Older guides say minimal has no Wi-Fi story — that was true on ≤25.05, which used
`wpa_supplicant`.)

Write it with [Rufus](https://rufus.ie) in **DD mode**. Rufus will offer ISO mode; that
rebuilds the bootloader rather than writing the image verbatim. It often works, but DD is
the mode that matches what the NixOS manual asks for. If you use Ventoy instead, know that
NixOS ISOs have a history of blank screens and stage-1 failures under it — re-flash with DD
before debugging anything else.

## 2. BIOS

Power on, tap **F1** for BIOS. **F12** gets the one-time boot menu.

- **Security → Secure Boot → Disabled.** The installer's EFI binary (GRUB, not
  systemd-boot) is unsigned and there is no shim, and the installed system's kernel and
  initrd are unsigned too. You can re-enable it later with
  [lanzaboote](https://github.com/nix-community/lanzaboote) if you care.
- Confirm boot mode is **UEFI** (default on this machine).
- Enable UEFI capsule updates if you want `fwupd` to work from Linux later.
- **Check the firmware version.** **0.1.40 is known-bad**: an `amd_sfh` null-deref means
  the machine cannot suspend, reboot, or shut down. If you're on it and didn't update in
  step 0, see Troubleshooting before you install.
- Do **not** look for a "Linux (S3)" sleep option — it was removed after 0.1.17 and this
  CPU generation is s2idle-only.

## 3. Acceptance test (before wiping anything)

This is your last easy moment to send the machine back. Boot the USB, open a terminal:

```bash
lscpu | grep -E 'Model name|^CPU\(s\)'      # Ryzen 7 PRO 6850U, 16 threads
free -h                                      # ~31Gi
lsblk -d -o NAME,SIZE,MODEL                  # ~476G NVMe
lspci | grep -iE 'vga|display'               # Radeon 680M (Rembrandt)
lspci | grep -i net                          # RZ616/MT7922 *or* Qualcomm NFA725A — both ship
```

Battery health. The kernel exposes **either** `energy_*` **or** `charge_*` depending on
what the battery reports in ACPI `_BIX` — never both — so a command hardcoding one errors
out on half of machines. This works either way:

```bash
b=/sys/class/power_supply/BAT0
f=$(cat $b/{energy,charge}_full 2>/dev/null | head -1)
d=$(cat $b/{energy,charge}_full_design 2>/dev/null | head -1)
awk -v f=$f -v d=$d 'BEGIN{printf "battery health: %.1f%%\n", 100*f/d}'
```

Get online (GNOME top-right menu, or `nmtui`):

```bash
nmcli device wifi connect "<SSID>" password "<password>"
ping -c3 nixos.org
```

## 4. Dry-run the config before you commit

You should already have done this on the desktop (see **Robustness** below). If you
haven't, do it now, while the machine still has a working OS on it:

```bash
nix --extra-experimental-features 'nix-command flakes' \
  build --no-link https://github.com/xnmp-setup/nixos-t14s/archive/main.tar.gz#nixosConfigurations.t14s.config.system.build.toplevel
```

If that fails, stop. Fixing a broken flake is much easier with an OS on the disk.

## 5. Partition — this destroys Windows

```bash
sudo -i
lsblk                      # CONFIRM the disk is nvme0n1 before continuing
```

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 1GB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart root 1GB 100%
```

## 6. Encrypt + format

```bash
cryptsetup luksFormat /dev/nvme0n1p2      # type YES, then set your passphrase
cryptsetup open /dev/nvme0n1p2 cryptroot  # same passphrase
```

Your LUKS passphrase is typed at boot on a **US layout**, before any config loads. Pick
something you can type blind.

```bash
mkfs.fat -F32 -n BOOT /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/nvme0n1p1 /mnt/boot
```

## 7. Generate the real hardware config

```bash
nixos-generate-config --root /mnt
```

**Verify it before continuing** — both of these must be present, or the installed system
will not boot / will have no Wi-Fi:

```bash
grep -A3 'luks'          /mnt/etc/nixos/hardware-configuration.nix   # boot.initrd.luks.devices."cryptroot"
grep    'not-detected'   /mnt/etc/nixos/hardware-configuration.nix   # pulls in redistributable firmware
```

The first must yield `boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/…";`.
(`modules/system.nix` also sets `hardware.enableRedistributableFirmware` explicitly, so the
second is belt-and-braces — but check it anyway.)

There will be no `swapDevices` entry, and that is correct: swap is declared in Nix.

## 8. Drop the flake in

```bash
mkdir -p /mnt/home/chong/Repos
git clone https://github.com/xnmp-setup/nixos-t14s /mnt/home/chong/Repos/nixos-t14s
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/chong/Repos/nixos-t14s/hosts/t14s/hardware-configuration.nix
```

**Commit it immediately.** The file is git-tracked, and the version in the repo is a
non-bootable placeholder. The flake will use your copy while the tree is dirty, so the
install works — but the first `git pull --rebase` or `git checkout .` on the installed
machine restores the placeholder, and the next rebuild produces a system with no LUKS
device. Unbootable, at a moment when you've long forgotten this step:

```bash
git -C /mnt/home/chong/Repos/nixos-t14s -c user.email=chonw89@gmail.com -c user.name=xnmp \
    commit -am 'hardware-configuration for t14s'
```

## 9. Install

```bash
nixos-install --flake /mnt/home/chong/Repos/nixos-t14s#t14s
```

15–40 minutes on Wi-Fi. Prompts for a **root** password at the end. Set one you'll
remember — it is your recovery path (see Robustness).

## 10. Set your user password — do not skip

The config defines user `chong` but no password. `greetd` will show a login prompt you
cannot answer:

```bash
nixos-enter --root /mnt -c 'passwd chong'
chown -R 1000:100 /mnt/home/chong     # the clone above is owned by root otherwise
```

## 11. Reboot

```bash
umount -R /mnt
reboot
```

Pull the USB. Expect: LUKS passphrase → tuigreet → log in as `chong` → Hyprland.

Hyprland will look completely bare until chezmoi runs — the compositor config lives there,
not here. That is not a failed install.

---

## First boot

```bash
chezmoi init --apply <your-dotfiles-repo>       # Hyprland, wezterm, zsh/p10k, scripts
curl -fsSL https://claude.ai/install.sh | bash  # Claude Code (native, self-updating)
sudo nixos-rebuild switch --flake ~/Repos/nixos-t14s#t14s
```

Add to your chezmoi hypr config, or polkit prompts will fail silently:

```
exec-once = systemctl --user start hyprpolkitagent
```

Then pair Syncthing with the desktop at <http://localhost:8384>.

---

## Robustness — how not to get stranded

The failure you actually care about is *"I wiped Windows and now nothing boots."* In rough
order of value:

1. **Build the closure on the desktop first.** Same architecture, same flake — every
   evaluation error and bad package name surfaces on a machine that still works:
   ```bash
   nix build --no-link .#nixosConfigurations.t14s.config.system.build.toplevel
   ```
2. **Boot it in a VM before touching the laptop.** This is the only way to see greetd and
   Hyprland actually come up, short of installing:
   ```bash
   nixos-rebuild build-vm --flake .#t14s && ./result/bin/run-t14s-vm
   ```
   The VM uses its own throwaway disk; it won't touch anything.
3. **Keep the installer USB.** It is the recovery tool. To get back into a broken system:
   ```bash
   cryptsetup open /dev/nvme0n1p2 cryptroot
   mount /dev/mapper/cryptroot /mnt && mount /dev/nvme0n1p1 /mnt/boot
   nixos-enter --root /mnt
   ```
4. **Generations are your undo.** Every rebuild leaves the previous system in the
   systemd-boot menu — hold **space** at boot to pick an older one. This is why a bad
   rebuild is nearly always recoverable, and why `configurationLimit` is left unset here.
5. **Use `nixos-rebuild boot` for risky changes**, not `switch`. Applies on next reboot,
   so a bad kernel or GPU change doesn't take down your running session.
6. **Root password + a TTY.** `greetd` owns tty1; **Ctrl+Alt+F2** gets a plain login. If
   Hyprland won't start, that's how you get in without the USB.
7. **Kernel params are editable at boot** — press **`e`** in systemd-boot. That's the
   escape hatch for the `amd_sfh` hang below, where you can't rebuild because the machine
   won't stay up long enough.
8. **Don't delete the old generation that worked.** `nix-collect-garbage -d` removes every
   rollback target. Avoid it until the machine has been stable for a while.

---

## Troubleshooting

**Screen flickers, shows corruption, or hard-freezes after suspend** — Panel Self Refresh.
Already mitigated by `amdgpu.dcdebugmask=0x10` in `modules/system.nix`. Still open upstream
([drm/amd#2735](https://gitlab.freedesktop.org/drm/amd/-/issues/2735)); drop the param when
a kernel fixes it, as it costs a little idle power.

**Cannot suspend, reboot, or shut down** — BIOS 0.1.40's `amd_sfh` null-deref. Looks
exactly like a broken NixOS install. You cannot rebuild your way out (the initrd rebuild
hangs), so press `e` in systemd-boot and append `modprobe.blacklist=amd_sfh`, boot, then
update firmware with `fwupdmgr update`.

**No passphrase prompt / drops to an initrd shell** — step 7's LUKS check failed. Boot the
USB, `cryptsetup open`, mount, re-run steps 7–9.

**BIOS skips straight past the disk** — Secure Boot came back on, or the ESP flag didn't
stick. Check `parted /dev/nvme0n1 print` for the `esp` flag.

**Mic-mute LED stuck on** — disable Auto-Mute Mode in `alsamixer`. The internal mic itself
works out of the box: both machine types (21CQ, 21CR) are in the mainline `acp6x-mach.c`
quirk table. Ignore any advice about `sof-firmware` — that's Intel-only.

**Fingerprint** — uncomment `services.fprintd.enable` in `modules/system.nix`. The sensor
is Goodix `27c6:6594` or Synaptics `06cb:00f9` depending on the unit; check `lsusb`, don't
hardcode.

**Battery** — thresholds are 40→80% (`modules/system.nix`), so you'll boot part-charged.
Before a long day out: `sudo tlp fullcharge`. One-shot, no rebuild, and TLP restores the
thresholds on the next unplug. Do **not** set `STOP_CHARGE_THRESH_BAT0 = 100` — on
ThinkPads that *disables* the threshold rather than targeting 100%. Verify with `tlp-stat -b`.

**No notifications** — no notification daemon is installed. Add `mako` to
`modules/hyprland.nix` and configure it via chezmoi.

**Not in nixpkgs** — `vicinae`, `lpm`, `rtk`, `bd/beads`, `ccstatusline` come via chezmoi or
their own installers.
