#!/bin/sh
# GreenBang Overlayfs Boot Script
# Mounts ISO as lower layer, tmpfs as upper layer
# Called from custom init before root switch

set -e

LOWER_DIR="/mnt/iso"
UPPER_DIR="/tmp/.overlay/upper"
WORK_DIR="/tmp/.overlay/work"
OVERLAY_MOUNT="/newroot"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "${GREEN}[overlayfs-init] Starting overlayfs setup${NC}"

# Step 1: Verify overlayfs kernel support
if ! grep -q "overlay" /proc/filesystems; then
    echo "${RED}[overlayfs-init] ERROR: overlayfs not supported by kernel${NC}"
    echo "[overlayfs-init] Falling back to traditional RAM-based boot"
    return 1
fi

echo "${GREEN}[overlayfs-init] Overlayfs kernel module available${NC}"

# Step 2: Verify lower layer (ISO) is mounted
if [ ! -d "$LOWER_DIR" ] || [ ! -e "$LOWER_DIR/etc/hostname" ]; then
    echo "${RED}[overlayfs-init] ERROR: Lower layer not ready at $LOWER_DIR${NC}"
    return 1
fi

echo "${GREEN}[overlayfs-init] Lower layer verified: $LOWER_DIR${NC}"

# Step 3: Create tmpfs for upper and work directories
mkdir -p "$UPPER_DIR" "$WORK_DIR"
if [ $? -ne 0 ]; then
    echo "${RED}[overlayfs-init] ERROR: Failed to create overlay directories${NC}"
    return 1
fi

echo "${GREEN}[overlayfs-init] Created overlay directories${NC}"

# Step 4: Mount overlayfs
mount -t overlay \
    -o lowerdir="$LOWER_DIR",upperdir="$UPPER_DIR",workdir="$WORK_DIR" \
    overlay "$OVERLAY_MOUNT"

if [ $? -ne 0 ]; then
    echo "${RED}[overlayfs-init] ERROR: Failed to mount overlayfs${NC}"
    return 1
fi

echo "${GREEN}[overlayfs-init] Overlayfs mounted successfully${NC}"

# Step 5: Verify mount
if [ ! -e "$OVERLAY_MOUNT/etc/hostname" ]; then
    echo "${RED}[overlayfs-init] ERROR: Overlayfs mount verification failed${NC}"
    umount "$OVERLAY_MOUNT" 2>/dev/null || true
    return 1
fi

echo "${GREEN}[overlayfs-init] Overlayfs verified and ready${NC}"
echo "${YELLOW}[overlayfs-init] RAM usage: upper layer only (changes)${NC}"

return 0
