#!/bin/sh -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname"
	exit 1
fi

cleanup() {
	rm -rf "$tmp"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

# Get the script directory (where apkovl-files is located)
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
APKOVL_FILES="$SCRIPTDIR/apkovl-files"

if [ ! -d "$APKOVL_FILES" ]; then
	echo "ERROR: apkovl-files directory not found at $APKOVL_FILES"
	exit 1
fi

# Copy overlay files from apkovl-files
cp -r "$APKOVL_FILES"/etc "$tmp"/

# Create hostname
mkdir -p "$tmp"/etc
echo "$HOSTNAME" > "$tmp"/etc/hostname

# Create network config
mkdir -p "$tmp"/etc/network
cat > "$tmp"/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Create package list
mkdir -p "$tmp"/etc/apk
cat > "$tmp"/etc/apk/world <<EOF
alpine-base
bash
xorg-server
xinit
xf86-input-libinput
xf86-video-vesa
openbox
xterm
lxterminal
sudo
mesa-dri-gallium
eudev
feh
dhcpcd
EOF

# Setup runlevels
rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add dhcpcd boot
rc_add local boot

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

# Generate apkovl
tar -c -C "$tmp" etc | gzip -9n > $HOSTNAME.apkovl.tar.gz
