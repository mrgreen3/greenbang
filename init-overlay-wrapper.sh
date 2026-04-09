#!/bin/sh
# Wrapper script inserted into Alpine initfs
# Attempts overlayfs boot, falls back to traditional if needed
# This replaces the standard linuxrc modloop setup

set -e

# Source the overlayfs init logic
. /etc/init-overlay.sh

# Attempt overlayfs setup
if overlayfs_setup; then
    echo "Using overlayfs boot"
    OVERLAYFS_ENABLED="yes"
else
    echo "Overlayfs failed, attempting fallback to RAM-based boot"
    OVERLAYFS_ENABLED="no"
    # Fallback: use traditional modloop setup (copy to RAM)
    # This would call the original modloop_setup function
fi

# Export for later use in init scripts
export OVERLAYFS_ENABLED

# Continue with normal Alpine boot
# The rest of linuxrc proceeds unchanged
