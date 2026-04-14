#!/bin/bash
set -e

# GreenBang build script with integrated overlayfs support
# Properly handles apkovl-files directory for live user and configs

PROJECTDIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="/var/tmp/greenbang-work-$$"
OUTDIR="$HOME/iso"
VERSION="${VERSION:-0.1.6}"
APORTS_SCRIPTS="${APORTS_SCRIPTS:-$HOME/aports/scripts}"
MKINITFS_ORIG="/tmp/initramfs-init.backup.$$"
MKINITFS_FILE="/usr/share/mkinitfs/initramfs-init"
CUSTOM_MKINITFS="$PROJECTDIR/mkinitfs/initramfs-init"

echo "=== GreenBang Build with Integrated Overlayfs Support ==="
echo "Project: $PROJECTDIR"
echo "Work dir: $WORKDIR"
echo "Output: $OUTDIR"
echo "Version: $VERSION"

# Cleanup function - restores initramfs-init and removes workdir (needs doas for rootfs)
cleanup() {
    if [ -f "$MKINITFS_ORIG" ]; then
        echo "Restoring original initramfs-init..."
        doas cp "$MKINITFS_ORIG" "$MKINITFS_FILE" 2>/dev/null || true
        doas rm -f "$MKINITFS_ORIG" 2>/dev/null || true
    fi
    doas umount "$WORKDIR/iso-mnt" 2>/dev/null || true
    doas rm -rf "$WORKDIR" 2>/dev/null || true
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

# Apply apkovl to rootfs: bakes hostname, runlevels, and setup scripts into squashfs lower layer.
# This ensures OpenRC finds runlevel symlinks and hostname is correct at boot,
# independent of overlay-merging behaviour at runtime.
echo "Applying apkovl configuration to rootfs..."
APKOVL_FILE=$(find "$ISO_MNT" -name "*.apkovl.tar.gz" 2>/dev/null | head -1)
if [ -n "$APKOVL_FILE" ]; then
    doas tar -xzf "$APKOVL_FILE" -C "$ROOTFS_DIR" 2>/dev/null || true
    doas chmod 755 "$ROOTFS_DIR/etc/local.d/greenbang-setup.start" 2>/dev/null || true
    echo "✓ apkovl baked into rootfs (hostname, runlevels, setup scripts)"
else
    echo "WARNING: No apkovl found in ISO - runlevels will be empty in squashfs"
fi

# Unmount ISO
doas umount "$ISO_MNT"

# Ensure essential mount-point directories exist as empty stubs in the squashfs.
# The -e flag on mksquashfs removes entire directories, leaving no /run mountpoint.
# Without /run, OpenRC cannot initialize at boot.
echo "Creating empty mount point stubs in rootfs..."
for dir in proc sys dev run tmp; do
    doas rm -rf "$ROOTFS_DIR/$dir"
    doas mkdir -p "$ROOTFS_DIR/$dir"
done
echo "✓ Mount point stubs created (proc sys dev run tmp)"

# Create squashfs — no -e exclusions so empty stub dirs are included as mount points
echo "Creating squashfs (xz compression)..."
doas mksquashfs "$ROOTFS_DIR" "$SQUASHFS_PATH" \
    -comp xz \
    -b 1048576 \
    -Xdict-size 100% \
    -noappend \
    -no-progress
echo "✓ rootfs.squashfs: $(ls -lh "$SQUASHFS_PATH" | awk '{print $5}')"

# Repack ISO with squashfs included
echo ""
echo "=== Repacking ISO with rootfs.squashfs ==="
mkdir -p "$ISO_REPACK_DIR"
doas mount -t iso9660 -o loop,ro "$ISO_PATH" "$ISO_MNT"
cp -a "$ISO_MNT/." "$ISO_REPACK_DIR/"
doas umount "$ISO_MNT"
doas chmod -R u+w "$ISO_REPACK_DIR"
rm -rf "$ISO_REPACK_DIR/apks"
echo "✓ APK cache removed (redundant — packages baked into squashfs)"

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

# Workdir is cleaned by the trap on EXIT
