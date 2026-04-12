#!/bin/bash
set -e

# GreenBang build script with integrated overlayfs support
# Properly handles apkovl-files directory for live user and configs

PROJECTDIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="/tmp/greenbang-work-$$"
OUTDIR="$HOME/iso"
VERSION="${VERSION:-0.1.3}"
APORTS_SCRIPTS="${APORTS_SCRIPTS:-$HOME/aports/scripts}"
MKINITFS_ORIG="/tmp/initramfs-init.backup.$$"
MKINITFS_FILE="/usr/share/mkinitfs/initramfs-init"
CUSTOM_MKINITFS="$PROJECTDIR/mkinitfs/initramfs-init"

echo "=== GreenBang Build with Integrated Overlayfs Support ==="
echo "Project: $PROJECTDIR"
echo "Work dir: $WORKDIR"
echo "Output: $OUTDIR"
echo "Version: $VERSION"

# Cleanup function to restore original initramfs-init
cleanup() {
    if [ -f "$MKINITFS_ORIG" ]; then
        echo "Restoring original initramfs-init..."
        doas cp "$MKINITFS_ORIG" "$MKINITFS_FILE" 2>/dev/null || true
        rm -f "$MKINITFS_ORIG"
    fi
}
trap cleanup EXIT

# Check if we're in a proper Alpine environment with mkimage
if [ ! -f "$APORTS_SCRIPTS/mkimage.sh" ]; then
    echo "ERROR: mkimage.sh not found at $APORTS_SCRIPTS/mkimage.sh"
    echo "Need to set up Alpine aports or set APORTS_SCRIPTS variable"
    exit 1
fi

# Check if custom initramfs-init exists
if [ ! -f "$CUSTOM_MKINITFS" ]; then
    echo "ERROR: $CUSTOM_MKINITFS not found"
    exit 1
fi

# Check if apkovl-files exists
if [ ! -d "$PROJECTDIR/apkovl-files" ]; then
    echo "ERROR: $PROJECTDIR/apkovl-files not found"
    exit 1
fi

# Create output directory
mkdir -p "$OUTDIR"

# Clean work directory
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

echo ""
echo "Setting up build files..."

# Symlink build script files
for f in mkimg.greenbang.sh genapkovl-greenbang.sh packages.list; do
    ln -sf "$PROJECTDIR/$f" "$APORTS_SCRIPTS/$f"
done

# CRITICAL: Copy apkovl-files instead of symlinking
# This ensures genapkovl-greenbang.sh finds it correctly when resolving paths
rm -rf "$APORTS_SCRIPTS/apkovl-files"
cp -r "$PROJECTDIR/apkovl-files" "$APORTS_SCRIPTS/apkovl-files"

echo "✓ Build files configured"

# Apply overlayfs patch to initramfs-init
echo ""
echo "Applying overlayfs patch to initramfs-init..."
doas cp "$MKINITFS_FILE" "$MKINITFS_ORIG"
doas cp "$CUSTOM_MKINITFS" "$MKINITFS_FILE"
echo "✓ Overlayfs-enabled initramfs-init installed"

# Change to mkimage scripts directory (required for genapkovl-greenbang.sh lookup)
cd "$APORTS_SCRIPTS"

echo ""
echo "Running mkimage.sh..."
export GB_VERSION="$VERSION"
sh mkimage.sh \
    --tag v3.23 \
    --outdir "$OUTDIR" \
    --workdir "$WORKDIR" \
    --arch x86_64 \
    --profile greenbang \
    --repository https://dl-cdn.alpinelinux.org/alpine/v3.23/main \
    --repository https://dl-cdn.alpinelinux.org/alpine/v3.23/community

# Find base ISO
ISO_PATH=$(ls "$OUTDIR"/greenbang-${VERSION}-x86_64.iso 2>/dev/null | head -1)
if [ -z "$ISO_PATH" ]; then
    echo "✗ ISO not found in $OUTDIR"
    exit 1
fi
echo ""
echo "✓ Base ISO built: $ISO_PATH ($(ls -lh "$ISO_PATH" | awk '{print $5}'))"

# Build rootfs.squashfs and inject into ISO
SQUASHFS_PATH="$OUTDIR/greenbang-${VERSION}-rootfs.squashfs"
ISO_REPACK_DIR="$WORKDIR/iso-repack"
ROOTFS_DIR="$WORKDIR/rootfs"

echo ""
echo "=== Building rootfs.squashfs ==="

# Mount the base ISO to access the APK cache
ISO_MNT="$WORKDIR/iso-mnt"
mkdir -p "$ISO_MNT"
doas mount -t iso9660 -o loop,ro "$ISO_PATH" "$ISO_MNT"

# Install packages into rootfs using the ISO's APK cache
mkdir -p "$ROOTFS_DIR"
echo "Installing packages to rootfs (using ISO APK cache)..."
doas apk add \
    --root "$ROOTFS_DIR" \
    --initdb \
    --no-progress \
    --repository "$ISO_MNT/apks" \
    --allow-untrusted \
    alpine-base \
    $(grep -v '^#' "$PROJECTDIR/packages.list" | grep -v '^$' | tr '\n' ' ')

echo "✓ Packages installed to rootfs"

# Unmount ISO
doas umount "$ISO_MNT"

# Create squashfs
echo "Creating squashfs (xz compression)..."
doas mksquashfs "$ROOTFS_DIR" "$SQUASHFS_PATH" \
    -comp xz \
    -noappend \
    -no-progress \
    -e proc sys dev run tmp
echo "✓ rootfs.squashfs: $(ls -lh "$SQUASHFS_PATH" | awk '{print $5}')"

# Repack ISO with squashfs included
echo ""
echo "=== Repacking ISO with rootfs.squashfs ==="
mkdir -p "$ISO_REPACK_DIR"
doas mount -t iso9660 -o loop,ro "$ISO_PATH" "$ISO_MNT"
cp -a "$ISO_MNT/." "$ISO_REPACK_DIR/"
doas umount "$ISO_MNT"
doas chmod -R u+w "$ISO_REPACK_DIR"

cp "$SQUASHFS_PATH" "$ISO_REPACK_DIR/rootfs.squashfs"
echo "✓ rootfs.squashfs added to ISO contents"

FINAL_ISO="$OUTDIR/greenbang-${VERSION}-x86_64.iso"
xorriso -as mkisofs \
    -o "$FINAL_ISO" \
    -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
    -c boot/syslinux/boot.cat \
    -b boot/syslinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    "$ISO_REPACK_DIR" 2>&1 | grep -v "^xorriso" | tail -5

echo ""
echo "=== Build Complete ==="
echo "ISO:     $FINAL_ISO ($(ls -lh "$FINAL_ISO" | awk '{print $5}'))"
echo "Squashfs: $SQUASHFS_PATH ($(ls -lh "$SQUASHFS_PATH" | awk '{print $5}'))"
echo ""
echo "To test: qemu-system-x86_64 -cdrom $FINAL_ISO -m 2g -enable-kvm -vga virtio"

# Cleanup work directory
rm -rf "$WORKDIR"
