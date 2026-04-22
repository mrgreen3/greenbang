#!/bin/sh
set -e

PROJECTDIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="/var/tmp/greenbang-work-$$"
OUTDIR="$HOME/iso"
VERSION="${GB_VERSION:-0.1.9-beta}"
TAG="${TAG:-v3.23}"
APORTS_SCRIPTS="${APORTS_SCRIPTS:-$HOME/aports/scripts}"
MKINITFS_FILE="/usr/share/mkinitfs/initramfs-init"
MKINITFS_BACKUP="/tmp/initramfs-init.backup.$$"

echo "=== GreenBang $VERSION ==="

if [ ! -f "$APORTS_SCRIPTS/mkimage.sh" ]; then
    echo "ERROR: mkimage.sh not found at $APORTS_SCRIPTS/mkimage.sh"
    exit 1
fi

cleanup() {
    if [ -f "$MKINITFS_BACKUP" ]; then
        doas cp "$MKINITFS_BACKUP" "$MKINITFS_FILE"
        doas rm -f "$MKINITFS_BACKUP"
    fi
    doas rm -rf "$WORKDIR" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$OUTDIR" "$WORKDIR"

for f in mkimg.greenbang.sh genapkovl-greenbang.sh packages.list; do
    ln -sf "$PROJECTDIR/$f" "$APORTS_SCRIPTS/$f"
done

rm -rf "$APORTS_SCRIPTS/apkovl-files"
cp -r "$PROJECTDIR/apkovl-files" "$APORTS_SCRIPTS/apkovl-files"

doas cp "$MKINITFS_FILE" "$MKINITFS_BACKUP"
doas cp "$PROJECTDIR/mkinitfs/initramfs-init" "$MKINITFS_FILE"

cd "$APORTS_SCRIPTS"

export GB_VERSION="$VERSION"
sh mkimage.sh     --tag "$TAG"     --outdir "$OUTDIR"     --workdir "$WORKDIR"     --arch x86_64     --profile greenbang     --repository https://dl-cdn.alpinelinux.org/alpine/v3.23/main     --repository https://dl-cdn.alpinelinux.org/alpine/v3.23/community

ISO="$OUTDIR/greenbang-${VERSION}-x86_64.iso"
if [ -f "$ISO" ]; then
    echo ""
    echo "=== Build complete ==="
    echo "ISO: $ISO ($(ls -lh "$ISO" | awk '{print $5}'))"
else
    echo "ERROR: ISO not found at $ISO"
    exit 1
fi
