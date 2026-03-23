#!/bin/sh
set -e

DESTDIR="$1"
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
AIROOTFS="$SCRIPTDIR/airootfs"

if [ -z "$DESTDIR" ]; then
    echo "ERROR: DESTDIR not provided"
    exit 1
fi

echo "Generating GreenBang apkovl overlay..."

# Copy airootfs to overlay
if [ -d "$AIROOTFS" ]; then
    echo "Copying overlay files from airootfs..."
    cp -a "$AIROOTFS"/* "$DESTDIR"/ 2>&1 || echo "Warning: some files may not have copied"
fi

# Ensure /etc/skel exists with proper structure
echo "Setting up /etc/skel..."
mkdir -p "$DESTDIR/etc/skel/.config/openbox"

# Create live user
echo "Creating live user..."
mkdir -p "$DESTDIR/etc/shadow.d"

# Add alpine user to /etc/passwd
if ! grep -q "^alpine:" "$DESTDIR/etc/passwd"; then
    cat >> "$DESTDIR/etc/passwd" << 'PASSWD'
alpine:x:1000:1000:Alpine User:/home/alpine:/bin/bash
PASSWD
fi

# Add alpine user to /etc/group
if ! grep -q "^alpine:" "$DESTDIR/etc/group"; then
    cat >> "$DESTDIR/etc/group" << 'GROUP'
alpine:x:1000:
wheel:x:10:alpine
GROUP
fi

# Set password (encrypted: "alpine")
if [ ! -f "$DESTDIR/etc/shadow.d/alpine" ]; then
    cat > "$DESTDIR/etc/shadow.d/alpine" << 'SHADOW'
alpine:$1$sORJx0BC$m4V2ggpvGwSMUTMEFQ7Ox1:19000:0:99999:7:::
SHADOW
fi

# Create home directory
echo "Creating home directory..."
mkdir -p "$DESTDIR/home/alpine"

# Copy /etc/skel contents to home
if [ -d "$DESTDIR/etc/skel" ]; then
    echo "Copying skel to home..."
    cp -r "$DESTDIR/etc/skel"/* "$DESTDIR/home/alpine/" 2>/dev/null || true
    cp -r "$DESTDIR/etc/skel"/.??* "$DESTDIR/home/alpine/" 2>/dev/null || true
fi

# Fix ownership
echo "Setting ownership..."
chown -R 1000:1000 "$DESTDIR/home/alpine"
chmod 755 "$DESTDIR/home/alpine"

# Enable getty on tty1 for live boot
mkdir -p "$DESTDIR/etc/runlevels/default"
if [ ! -L "$DESTDIR/etc/runlevels/default/agetty.tty1" ]; then
    ln -s /etc/init.d/agetty "$DESTDIR/etc/runlevels/default/agetty.tty1"
fi

echo "Overlay generation complete"
