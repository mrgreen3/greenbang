# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

GreenBang is an Alpine Linux live ISO distribution with a Wayland desktop (labwc compositor). It builds a bootable ISO using Alpine's `mkimage.sh` toolchain.

## Build

From the VM only — never run builds on the local host:

```sh
# Always pull before building
git pull

# Run the build
./build-greenbang.sh
```

Output ISO lands in `~/iso/greenbang-x86_64.iso`. After every build, test with QEMU:

```sh
qemu-system-x86_64 -cdrom ~/iso/greenbang-x86_64.iso -m 512m -nographic
```

Do not skip the QEMU test. Do not hand results back until the boot test passes.

## Architecture

The build uses two Alpine-specific files that must stay in sync:

**`mkimg.greenbang.sh`** — the ISO profile. Defines packages fetched into the ISO at build time via the `apks=` variable. Reads `packages.list` and appends it to `apks`. Also overrides `section_kernels()` to use selective firmware instead of the full `linux-firmware` meta-package.

**`genapkovl-greenbang.sh`** — the overlay script. Defines what the live system looks like at boot: copies `apkovl-files/etc/` into a tarball, writes `/etc/apk/world` (packages installed at boot), adds OpenRC service symlinks via `rc_add()`. Must end with the `tar | gzip` line — do not change this.

**Critical sync rule:** Every package in `/etc/apk/world` (written by genapkovl) must also appear in `apks=` (profile). If a package is in world but not in apks, it won't exist on the ISO and will fail silently at boot.

**`packages.list`** — single source of truth for the desktop package set. Comments with `#`, one package per line. Both the profile and world file derive from this.

**`build-greenbang.sh`** — wrapper that symlinks project files into `~/aports/scripts/`, then calls `mkimage.sh` with the greenbang profile and Alpine 3.23 repositories.

## Overlay Files (`apkovl-files/etc/`)

Static config files that get copied into the live ISO overlay:

- `local.d/greenbang-setup.start` — creates the `live` user (uid 1000) at boot via the `local` OpenRC service. Idempotent.
- `doas.d/doas.conf` — grants wheel group `doas` access with `persist`
- `skel/` — copied to every new user's home. Contains all desktop configs.

### Desktop Stack (Wayland)

- **Compositor:** labwc (`skel/.config/labwc/rc.xml`) — config root element is `<labwc_config>`, not `<openbox_config>`
- **Autostart:** `skel/.config/labwc/autostart` — launches swaybg, waybar, polkit agent, mako, nm-applet, conky
- **Environment:** `skel/.config/labwc/environment` — sets cursor theme, keyboard layout
- **Panel:** waybar (`skel/.config/waybar/`)
- **Terminal:** foot (`skel/.config/foot/foot.ini`)
- **Launcher:** wmenu via `skel/.local/bin/wmenu-launcher`
- **Notifications:** mako (`skel/.config/mako/config`)
- **Themes:** `skel/.local/share/themes/` — Lightwave (active) and Seafront

### Key Keybindings

| Key | Action |
|-----|--------|
| Super+Return / Super+t | foot terminal |
| Super+d | wmenu launcher |
| Super+Space | root menu |
| Super+q | close window |
| Super+[1-4] | switch workspace |
| Super+Ctrl+←↑→↓ | snap to edge |
| Super+Ctrl+c | centre 80% |
| Super+Alt+e | exit labwc |

## Known Issues

- Mesa/LLVM full stack pulled in as xorg/xwayland dep — primary driver of large ISO size (~1.4GB vs 400–600MB target)
- `python3` pulled in transitively — source not yet identified
- `profile_base` includes `tiny-cloud-alpine`, `openssh`, `dhcpcd`, `openntpd` — all stripped in `mkimg.greenbang.sh`

## Live User

Username: `live`, password: `live`. Created by `greenbang-setup.start` on first boot. Member of: wheel, video, input, tty, audio, seat.
