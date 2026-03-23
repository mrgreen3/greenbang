#!/bin/bash
set -e

# GreenBang build script
# Requires: Alpine aports at ~/aports

PROJECTDIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="/tmp/greenbang-work-$$"
OUTDIR="$HOME/iso"
APORTS_SCRIPTS="${APORTS_SCRIPTS:-$HOME/aports/scripts}"

echo "=== GreenBang Build ==="
echo "Project: $PROJECTDIR"
echo "Work dir: $WORKDIR"
echo "Output: $OUTDIR"

# Check if we're in a proper Alpine environment with mkimage
if [ ! -f "$APORTS_SCRIPTS/mkimage.sh" ]; then
    echo "ERROR: mkimage.sh not found at $APORTS_SCRIPTS/mkimage.sh"
    echo "Need to set up Alpine aports or set APORTS_SCRIPTS variable"
    exit 1
fi

# Create output directory
mkdir -p "$OUTDIR"

# Clean work directory
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# Change to mkimage scripts directory (required for genapkovl-greenbang.sh lookup)
cd "$APORTS_SCRIPTS"

echo "Running mkimage.sh..."
sh mkimage.sh \
    --tag edge \
    --outdir "$OUTDIR" \
    --workdir "$WORKDIR" \
    --arch x86_64 \
    --profile greenbang \
    --repository https://mirrors.ircam.fr/pub/alpine/edge/main \
    --repository https://mirrors.ircam.fr/pub/alpine/edge/community

# Find and display output ISO
ISO_PATH=$(ls "$OUTDIR"/greenbang-*.iso 2>/dev/null | head -1)
if [ -n "$ISO_PATH" ]; then
    echo ""
    echo "✓ Build successful!"
    echo "✓ ISO: $ISO_PATH"
    ls -lh "$ISO_PATH"
else
    echo "✗ ISO not found in $OUTDIR"
    exit 1
fi

# Cleanup work directory
rm -rf "$WORKDIR"

echo ""
echo "Next: Test with QEMU"
echo "  qemu-system-x86_64 -cdrom $ISO_PATH -m 512 -nographic"
