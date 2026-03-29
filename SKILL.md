# GreenBang Alpine ISO Build Skill

## Overview

GreenBang is an Alpine Linux based live ISO distribution inspired by the original CrunchBang Linux. It uses a labwc/Wayland desktop stack with waybar, foot terminal, rofi launcher and swaybg for wallpaper. The domain greenbang.org is owned. Claude Code runs directly on the Alpine build VM.

---

## Alpine ISO Build Architecture

Alpine's live ISO build is fundamentally different from Archiso. Do not apply Arch Linux thinking. Two separate files work together:

### File 1: mkimg.greenbang.sh — The Profile

Defines what goes into the ISO. The `apks=` line physically fetches packages AND their dependencies into the ISO cache at build time. mkimage handles dependency resolution automatically. Every package the live system needs must appear here.

Inherits from `profile_base`. Strip unwanted base packages explicitly:

```sh
profile_greenbang() {
    profile_base
    title="GreenBang"
    desc="Alpine Linux labwc desktop distribution"
    image_ext="iso"
    arch="x86_64"
    output_format="iso"
    hostname="greenbang"
    kernel_flavors="lts"
    kernel_addons=""

    # Strip unwanted base packages
    apks="$(echo $apks | sed 's/tiny-cloud-alpine//')"
    apks="$(echo $apks | sed 's/openssh//')"
    apks="$(echo $apks | sed 's/dhcpcd//')"
    apks="$(echo $apks | sed 's/openntpd//')"

    # Load packages from packages.list
    SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
    _pkglist="$(grep -v '^#' "$SCRIPTDIR/packages.list" | grep -v '^$' | tr '\n' ' ')"
    apks="$apks $_pkglist"

    apkovl="genapkovl-greenbang.sh"
}
```

### File 2: genapkovl-greenbang.sh — The Overlay

Defines what the live system looks like at boot: users, services, configs, and the `/etc/apk/world` file.

**Critical rule:** If a package is in world but not in `apks=` in the profile it will not exist on the ISO and will fail silently at boot. Both lists must match.

Must follow the exact structure of `~/aports/scripts/genapkovl-dhcp.sh`. Use `makefile()` and `rc_add()` functions exactly as shown there. Must end with:

```sh
tar -c -C "$tmp" . | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
```

Do not use DESTDIR, airootfs, or shadow.d — these are Arch/Debian concepts.

### packages.list

One package per line, comments with `#` supported, grouped logically. Read by the profile via:

```sh
_pkglist="$(grep -v '^#' "$SCRIPTDIR/packages.list" | grep -v '^$' | tr '\n' ' ')"
apks="$apks $_pkglist"
```

---

## profile_base Contents

profile_base provides the kernel, initfs and these base packages:

```
alpine-base apk-cron busybox chrony dhcpcd doas e2fsprogs
kbd-bkeymaps network-extras openntpd openssl openssh
tzdata wget tiny-cloud-alpine
```

Strip unwanted ones as shown above. `doas` is included — configure it in the overlay.

---

## Required Repositories

Both main and community are needed. community provides labwc, waybar, rofi-wayland, xsetroot and others:

```
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
```

---

## Desktop Stack Packages

```
# Wayland compositor and session
labwc
elogind
dbus-x11

# Terminal and launcher
foot
rofi-wayland

# Panel and wallpaper
waybar
swaybg

# Networking
networkmanager
networkmanager-wifi
networkmanager-applet
wpa_supplicant

# File manager
pcmanfm

# Fonts
font-dejavu
```

---

## Services in genapkovl

```sh
# sysinit
rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

# boot
rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add elogind boot

# default
rc_add networking default
rc_add networkmanager default
rc_add dbus default
rc_add local default
```

---

## User Setup

Created via `/etc/local.d/greenbang-setup.start` which runs via the `local` OpenRC service. Must be idempotent:

```sh
#!/bin/sh
if ! id -u greenbang >/dev/null 2>&1; then
    adduser -D -G wheel greenbang
    echo "greenbang:greenbang" | chpasswd
    addgroup greenbang audio
    addgroup greenbang video
    addgroup greenbang input
    addgroup greenbang seat
fi
```

Place via makefile() in genapkovl with permissions 0755.

---

## doas Configuration

doas is included in profile_base. Configure in overlay:

```sh
makefile root:root 0400 etc/doas.conf <<EOF
permit persist :wheel
EOF
```

---

## labwc Session Startup

labwc is started via dbus-launch. Add to the live user's profile or via a session script:

```sh
dbus-launch labwc
```

Config files go in `/etc/skel/.config/labwc/` in the overlay:
- `rc.xml` — keybindings, theme, window behaviour
- `menu.xml` — right-click menu
- `autostart` — starts waybar, swaybg, nm-applet, rofi etc
- `environment` — Wayland environment variables

foot config goes in `/etc/skel/.config/foot/foot.ini`

waybar config goes in `/etc/skel/.config/waybar/`

rofi config goes in `/etc/skel/.config/rofi/`

---

## Known Issues and Gotchas

**Shell:** Alpine uses busybox ash by default, not bash. Any config or script hardcoded to `/bin/bash` will fail. foot.ini login_shell setting needs to point to the correct shell.

**Mesa/LLVM:** Full Mesa stack and llvm21-libs are pulled in as dependencies causing significant image bloat. Current image size is approximately 650MB. For a vesa-only or basic GPU setup the full Mesa stack may be unavoidable as xorg-server and labwc both depend on it.

**Community repo not active on live system:** The live ISO boots without community repository enabled. A repo setup script (`greenbang-repos`) is provided in `/usr/local/bin/` to configure repositories with doas. Ensure doas and the script are in the image.

**dhcpcd vs NetworkManager:** profile_base includes dhcpcd. Strip it and use NetworkManager exclusively to avoid conflicts.

**python3:** Appears in installed packages with no clear justification. Investigate what pulls it in if image size becomes a concern.

**xterm:** May appear as a dependency of something. Use lxterminal or foot instead — remove xterm if found.

---

## Build Workflow

All building happens on the Alpine VM. Never run mkimage.sh on the host machine.

```sh
# On VM — always pull latest before building
git pull

# Build
cd ~/aports/scripts
sh mkimage.sh \
    --tag edge \
    --outdir ~/iso \
    --workdir /tmp/greenbang-work \
    --arch x86_64 \
    --profile greenbang \
    --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
    --repository https://dl-cdn.alpinelinux.org/alpine/edge/community

# Test every build in QEMU before considering it done
qemu-system-x86_64 -cdrom ~/iso/greenbang-*.iso -m 512m -nographic
```

---

## GreenBang Vision

Dark minimal desktop in the spirit of original CrunchBang:
- labwc compositor, Wayland native
- waybar panel, dark theme
- foot terminal
- rofi application launcher
- swaybg for wallpaper
- nm-applet in waybar tray
- Right-click menu via labwc menu.xml
- Welcome script on first boot
- Genuinely small and fast
- Terminal first approach

---

## Installer — setup-greenbang

GreenBang uses Alpine's own setup scripts as the foundation for installation. Do not reinvent what Alpine already provides — wrap and extend it.

### Location
```
/usr/local/bin/setup-greenbang
```

Follows Alpine naming convention — setup-alpine, setup-desktop, setup-disk, setup-greenbang. Users familiar with Alpine will immediately understand what it does. Must be in packages.list and baked into the ISO image.

### Approach
- Wrap Alpine's own setup scripts in a GreenBang branded experience
- Call each setup-* script in logical order
- Add GreenBang specific steps after base install completes
- Keep it simple — Alpine's scripts are reliable, use them

### Install Order
1. Welcome message — GreenBang branding
2. Keyboard layout — `setup-keymap`
3. Hostname — `setup-hostname`
4. Network — NetworkManager is already running on live system
5. Timezone — `setup-timezone`
6. Repositories — call `greenbang-repos` script first
7. Root password — `passwd`
8. Create user — `adduser` with correct groups (audio video input seat wheel)
9. Disk setup — `setup-disk`
10. Copy GreenBang configs to installed system
11. Setup bootloader — handled by setup-disk
12. Reboot prompt

### Notes
- setup-disk handles partitioning, formatting and base Alpine install
- GreenBang configs must be explicitly copied to installed system after setup-disk
- /etc/skel copies automatically for new users created after install
- greenbang-repos must run before setup-disk so packages are available
- doas must be configured on installed system — copy /etc/doas.conf
- Repos script location: `/usr/local/bin/greenbang-repos`
- Both scripts must be executable and present in the ISO image

### grub_mod for UEFI Boot

The full grub_mod set is required for UEFI boot — do not trim it:

```sh
grub_mod="all_video disk part_gpt part_msdos linux normal configfile search search_label efi_gop fat iso9660 cat echo ls test true help gzio multiboot2 efi_uga"
```

Missing `iso9660` or `configfile` causes grub to drop to a prompt on UEFI boot.

---

## Rules for Claude

- Execute multi-step commands without stopping to confirm each step
- Only pause on unexpected errors or genuine decisions
- Always run `git pull` on VM before building
- Always test in QEMU after every build
- Do not add packages beyond the current stated goal
- Do not skip build/test cycles
- Work on the VM — never run builds locally
