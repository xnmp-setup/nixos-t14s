# Installing on the T14s (wipe Windows, LUKS + ext4)

Target: ThinkPad T14s Gen 3 AMD, 512GB NVMe. This **erases the whole disk**, including
Windows. Back up anything on it first — there is no undo after step 4.

Layout produced:

```
/dev/nvme0n1p1   1GB    FAT32, ESP           -> /boot   (unencrypted, required)
/dev/nvme0n1p2   rest   LUKS2 -> ext4        -> /       (encrypted)
                        + 8GB swapfile at /.swapfile
```

---

## 0. Before you leave Windows

- Copy off anything you want to keep.
- Note your Wi-Fi SSID + password. **The T14s Gen 3 has no Ethernet port**, so the
  installer needs Wi-Fi to fetch packages.

## 1. Make the USB (from Windows)

1. Download the **GNOME graphical** ISO from <https://nixos.org/download/#nixos-iso>.
   Take the graphical one, not minimal — it has a Wi-Fi applet and `git`, which the
   minimal ISO makes you fight for.
2. Write it with [Rufus](https://rufus.ie) in **DD mode** (it will prompt; pick DD, not ISO)
   or with [Ventoy](https://ventoy.net).

## 2. BIOS

Power on, tap **F1** to enter BIOS.

- **Security → Secure Boot → Disabled.** Required: systemd-boot is unsigned and will
  not boot with Secure Boot on.
- Confirm boot mode is **UEFI** (it is by default on this machine).
- Save and exit (F10).

Tap **F12** during the next boot to pick the USB.

## 3. Acceptance test (do this before wiping anything)

Open a terminal in the live session. Confirm you got the machine you paid for — this is
your last easy moment to send it back:

```bash
lscpu | grep -E 'Model name|^CPU\(s\)'                  # Ryzen 7 PRO 6850U, 16 threads
free -h                                                  # ~31Gi
lsblk -d -o NAME,SIZE,MODEL                              # ~476G NVMe
lspci | grep -iE 'vga|display'                           # Radeon 680M (Rembrandt)
cat /sys/class/power_supply/BAT0/charge_full{,_design}   # health = full ÷ design
```

Get online (GNOME top-right menu), or:

```bash
nmcli device wifi connect "<SSID>" password "<password>"
ping -c3 nixos.org
```

## 4. Partition — this destroys Windows

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

## 5. Encrypt + format

```bash
cryptsetup luksFormat /dev/nvme0n1p2      # type YES, then set your passphrase
cryptsetup open /dev/nvme0n1p2 cryptroot  # same passphrase
```

Your LUKS passphrase is typed at boot on a **US layout** keyboard, before any config
loads. Pick something you can type blind.

```bash
mkfs.fat -F32 -n BOOT /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/mapper/cryptroot
```

```bash
mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/nvme0n1p1 /mnt/boot
```

Swapfile (8GB — enough headroom on 32GB RAM; no hibernation):

```bash
dd if=/dev/zero of=/mnt/.swapfile bs=1M count=8192 status=progress
chmod 600 /mnt/.swapfile
mkswap /mnt/.swapfile
swapon /mnt/.swapfile
```

## 6. Generate the real hardware config

```bash
nixos-generate-config --root /mnt
```

**Verify it detected the encryption** — if this greps empty, stop and fix it, otherwise
the installed system will not boot:

```bash
grep -A3 'luks' /mnt/etc/nixos/hardware-configuration.nix
```

You want a `boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/...";`
line. You should also see the swapfile under `swapDevices`.

## 7. Drop the flake in

```bash
mkdir -p /mnt/home/chong/Repos
git clone https://github.com/xnmp-setup/nixos-t14s /mnt/home/chong/Repos/nixos-t14s
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/chong/Repos/nixos-t14s/hosts/t14s/hardware-configuration.nix
```

## 8. Install

```bash
nixos-install --flake /mnt/home/chong/Repos/nixos-t14s#t14s
```

Expect 15–40 minutes on Wi-Fi. It prompts for a **root** password at the end.

## 9. Set your user password — do not skip

The config defines the user `chong` but no password. `greetd` will show you a login
prompt you cannot answer, and you'd be recovering from a TTY. Set it now:

```bash
nixos-enter --root /mnt -c 'passwd chong'
chown -R 1000:100 /mnt/home/chong     # the clone above is owned by root otherwise
```

## 10. Reboot

```bash
umount -R /mnt
swapoff /mnt/.swapfile 2>/dev/null
reboot
```

Pull the USB. You should get: LUKS passphrase prompt → tuigreet → log in as `chong` →
Hyprland. Hyprland will look bare until chezmoi runs — that's expected, the compositor
config lives there, not here.

---

## First boot

```bash
# dotfiles: Hyprland, wezterm, zsh/p10k, scripts
chezmoi init --apply <your-dotfiles-repo>

# Claude Code (native installer, self-updating — deliberately not in the flake)
curl -fsSL https://claude.ai/install.sh | bash

# from here on, iterate with:
sudo nixos-rebuild switch --flake ~/Repos/nixos-t14s#t14s
```

Then set up Syncthing at <http://localhost:8384> to pair with the desktop.

## Things to check once you're in

- **Battery thresholds** are set to charge 40→80% (`modules/system.nix`). Great for desk
  use, but you'll boot with a part-full battery. Before a long day out, raise
  `STOP_CHARGE_THRESH_BAT0` to 100 and rebuild. Verify with `tlp-stat -b`.
- **Fingerprint reader** is commented out in `modules/system.nix`. Uncomment
  `services.fprintd.enable` if you want it.
- **No notification daemon** is installed — add `mako` to `modules/hyprland.nix` if
  Hyprland feels silent.
- **`vicinae`, `lpm`, `rtk`, `bd/beads`, `ccstatusline`** aren't in nixpkgs; they come
  via chezmoi or their own installers.
- **HW video decode**: `vainfo` should list VAProfileH264 etc.

## If it doesn't boot

- **Drops to an initrd prompt / no passphrase asked** — step 6's LUKS check failed.
  Boot the USB again, `cryptsetup open`, mount, and re-run steps 6–8.
- **BIOS skips straight past the disk** — Secure Boot came back on, or the ESP didn't
  get flagged. Recheck `parted /dev/nvme0n1 print` for the `esp` flag.
- **Recovering anything**: boot the USB, `cryptsetup open /dev/nvme0n1p2 cryptroot`,
  `mount /dev/mapper/cryptroot /mnt`, `mount /dev/nvme0n1p1 /mnt/boot`, then
  `nixos-enter --root /mnt`.
