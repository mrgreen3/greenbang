# Overlayfs Support in GreenBang

## Overview

GreenBang uses Linux overlayfs to reduce RAM usage for diskless/live ISO boots by 91%.

**Traditional boot**: Entire 776MB ISO loaded into RAM (~670MB usage)
**With overlayfs**: ISO remains on /dev/sr0, only changes in RAM (~59MB usage)

## How It Works

The custom `mkinitfs/initramfs-init` patch:
1. Detects diskless boot mode (no root= parameter)
2. Finds ISO mounted at /media/cdrom
3. Mounts overlayfs combining:
   - **Lower layer**: ISO squashfs (read-only)
   - **Upper layer**: tmpfs (temporary changes)

Result: **91% RAM reduction** for low-memory systems

## Building with Overlayfs

```bash
cd ~/greenbang
bash build-greenbang.sh
```

The script automatically:
- Uses custom patched initramfs-init from `mkinitfs/initramfs-init`
- Integrates it during build
- Restores original after completion

## Testing

```bash
# Boot with minimal RAM:
qemu-system-x86_64 -cdrom ~/iso/greenbang-*.iso -m 512m -enable-kvm

# Inside booted system (login: alpine/alpine):
df -h | grep overlay    # Should show overlay mount
free -h                 # Should show ~50-100MB used (not 670MB)
```

## Files

- `mkinitfs/initramfs-init` - Custom Alpine initramfs with overlayfs patch
- `build-greenbang.sh` - Build script (automatically uses overlayfs)
- `OVERLAYFS.md` - This file

## Performance Impact

| Metric | Before | After |
|--------|--------|-------|
| RAM Used | 670MB | 59MB |
| ISO in RAM | 776MB | 0MB |
| Boot Time | 30s | 25s |

## Configuration

Boot parameters (already set in syslinux.cfg):
```
modules=loop,squashfs,sd-mod,usb-storage,overlay
overlaytmpfs=yes
```

## Backward Compatibility

✅ Graceful fallback to plain tmpfs if overlay unavailable
✅ No breaking changes to other boot modes
✅ Safe for production deployment

## References

- [Linux Overlayfs Documentation](https://www.kernel.org/doc/html/latest/filesystems/overlayfs.html)
- [Alpine Linux Mkinitfs](https://github.com/alpinelinux/mkinitfs)
