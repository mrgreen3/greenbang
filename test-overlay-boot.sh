#!/bin/bash
# Test overlayfs boot on 1GB and 2GB QEMU systems

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISO_PATH="${1:-$HOME/iso/greenbang-*.iso}"
RAM_SIZE="${2:-1024}"  # Default 1GB, can override with 2nd arg

# Find latest ISO if wildcard
if [[ "$ISO_PATH" == *"*"* ]]; then
    ISO_PATH=$(ls -t $ISO_PATH 2>/dev/null | head -1)
fi

if [ ! -f "$ISO_PATH" ]; then
    echo "ERROR: ISO not found at $ISO_PATH"
    echo "Usage: $0 <iso-path> [ram-in-mb]"
    echo "Example: $0 ~/iso/greenbang-*.iso 1024"
    exit 1
fi

echo "================================"
echo "GreenBang Overlayfs Boot Test"
echo "================================"
echo "ISO: $ISO_PATH"
echo "RAM: ${RAM_SIZE}MB"
echo ""
echo "Boot sequence:"
echo "1. QEMU boots with ISO"
echo "2. Watch for overlayfs mount messages"
echo "3. Look for 'RAM usage: upper layer only'"
echo "4. Login as alpine / alpine"
echo "5. Run: df -h (check mount types)"
echo "6. Type 'exit' to quit"
echo ""

# Calculate timeout based on RAM size
if [ "$RAM_SIZE" -lt 1024 ]; then
    TIMEOUT=60
else
    TIMEOUT=45
fi

echo "Timeout: ${TIMEOUT}s"
echo "Starting QEMU (press Ctrl+A then X to exit)..."
echo ""

qemu-system-x86_64 \
    -cdrom "$ISO_PATH" \
    -m "$RAM_SIZE" \
    -vga virtio \
    -enable-kvm \
    -serial stdio \
    -monitor none

echo ""
echo "Test complete. Check output above for overlayfs messages."
