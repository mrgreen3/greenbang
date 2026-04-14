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

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	mkdir -p "$(dirname "$FILENAME")"
	cat > "$FILENAME"
	chmod "$PERMS" "$FILENAME"
	chown "$OWNER" "$FILENAME"
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
if [ -d "$APKOVL_FILES/usr" ]; then
	cp -r "$APKOVL_FILES"/usr "$tmp"/
fi

# Create hostname
mkdir -p "$tmp"/etc
echo "$HOSTNAME" > "$tmp"/etc/hostname

# Create os-release file with version
mkdir -p "$tmp"/etc
cat > "$tmp"/etc/os-release <<EOF2
NAME="GreenBang"
ID=greenbang
ID_LIKE=alpine
VERSION_ID="${GB_VERSION:-0.1.0}"
PRETTY_NAME="GreenBang ${GB_VERSION:-0.1.0}"
HOME_URL="https://greenbang.org"
DOCUMENTATION_URL="https://greenbang.org"
SUPPORT_URL="https://github.com/mrgreen3/greenbang"
BUG_REPORT_URL="https://github.com/mrgreen3/greenbang/issues"
PLATFORM_ID="linux"
EOF2

# Create network config (loopback only — NetworkManager handles everything else)
mkdir -p "$tmp"/etc/network
cat > "$tmp"/etc/network/interfaces <<EOF2
auto lo
iface lo inet loopback
EOF2

# Create package list from packages.list
mkdir -p "$tmp"/etc/apk
grep -v '^#' "$SCRIPTDIR/packages.list" | grep -v '^$' \
    | grep -v -E '^(linux-lts|grub|grub-efi)$' > "$tmp"/etc/apk/world

# Create /home directory for user creation at boot
mkdir -p "$tmp"/home

# ============================================================================
# Setup runlevels
# ============================================================================

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add udev sysinit
rc_add udev-trigger sysinit
rc_add udev-settle sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add local default

rc_add dbus default
rc_add networkmanager default
rc_add seatd default
rc_add rtkit default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

# Ensure root directory is readable/traversable by all users
chmod 755 "$tmp"

# Generate apkovl
# Remove /lib/modules since modloop already has it
rm -rf "$tmp/lib/modules"
tar -c -C "$tmp" . | gzip -9n > $HOSTNAME.apkovl.tar.gz
