#!/bin/sh
# Run inside QEMU to verify overlayfs is active

echo "=== Overlayfs Check ==="
echo ""

# Check if overlayfs is mounted
if grep -q "^overlay" /proc/mounts; then
    echo "✓ Overlayfs active"
    echo ""
    echo "Mount details:"
    grep "^overlay" /proc/mounts
else
    echo "✗ Overlayfs not active"
    echo "Using traditional boot"
fi

echo ""
echo "=== Filesystem Usage ==="
df -h | grep -E "^/dev|^overlay|^tmpfs|Filesystem"

echo ""
echo "=== Memory Usage ==="
free -h

echo ""
echo "=== Layer Check ==="
if [ -d "/tmp/.overlay/upper" ]; then
    echo "Upper layer size:"
    du -sh /tmp/.overlay/upper
fi
