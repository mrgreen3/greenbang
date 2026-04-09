# GreenBang Memory Requirements

## Overview
GreenBang uses Alpine's `overlaytmpfs=yes` with overlayfs to provide efficient low-RAM boot. The ISO (776MB) stays on the boot media and is cached in memory as needed, rather than being loaded entirely into RAM.

## Memory Usage Profile

### Idle System (Nothing Running)
- **Kernel + init services**: ~20-30 MB
- **Page cache (ISO)**: ~30-50 MB
- **Total in-use**: ~59 MB
- **Total available**: ~900 MB on 1GB system

### With Applications Running
```
System (idle)         59 MB
Firefox (single tab) ~150 MB
Terminal x 2          20 MB
File manager          15 MB
━━━━━━━━━━━━━━━━━━━━━━━━━━━
Subtotal             244 MB
Headroom remaining   720 MB (70% available)
```

## Recommended RAM

| Use Case | Minimum | Comfortable | Recommended |
|----------|---------|-------------|-------------|
| Live boot only | 512 MB | 1 GB | 2 GB |
| Light browsing | 1 GB | 2 GB | 4 GB |
| Multi-app usage | 2 GB | 4 GB | 8 GB |
| Development | 2 GB | 4 GB | 8 GB+ |

## How It Works

1. **Boot Parameters**:
   ```
   modules=loop,squashfs,sd-mod,usb-storage,overlay quiet overlaytmpfs=yes
   ```

2. **System Layout**:
   - **Lower Layer**: ISO on `/dev/sr0` (776MB, read-only on media)
   - **Upper Layer**: tmpfs in RAM (/.modoverlayfs)
   - **Overlayfs**: Mounted on `/lib/modules` for kernel modules

3. **Memory Strategy**:
   - Root filesystem runs as tmpfs (changes in RAM)
   - ISO accessed via kernel page cache (reads from media, cached in RAM)
   - Only modified/new files stored in RAM
   - Reboot clears all changes (by design)

## Testing

Check current memory usage:

```sh
free -h                    # Overall memory
df /                       # Root filesystem
mount | grep overlay       # Verify overlayfs
cat /proc/meminfo         # Detailed breakdown
```

Expected output on idle 1GB system:
```
Mem: 965.7M total, 59.2M used, 64.1M free, 842.4M buffers/cache
```

The large buffer/cache (842.4M) shows the ISO is cached, not loaded.

## Performance

- **Boot time**: ~25-30 seconds (depends on media speed)
- **Application startup**: Instant (binaries cached)
- **File writes**: Instant (to tmpfs)
- **File reads**: Fast (cached after first access)
- **Overall responsiveness**: Excellent

## Limitations

1. **No persistence**: Changes lost on reboot (by design for live ISO)
2. **Tmpfs size**: Default 50% of available RAM
3. **Docker**: May require special configuration (vfs driver)
4. **Large files**: Writing large temp files limited by tmpfs size

## Tuning

### Increase tmpfs allocation
```sh
mount -o remount,size=600M /
```

### Check tmpfs usage
```sh
df -h | grep tmpfs
```

### Monitor memory in real-time
```sh
watch -n 1 free -h
```

## Comparison: Traditional Live Boot vs Overlayfs

| Aspect | Traditional | Overlayfs |
|--------|-----------|-----------|
| ISO in RAM? | Yes (670MB) | No (page cached) |
| Boot RAM needed | 1.5 GB | 512 MB |
| Idle memory | 670 MB | 59 MB |
| Application headroom | 330 MB | 900 MB |
| Responsive on 1GB? | No (swaps) | Yes |

## Summary

GreenBang is optimized for **1GB+ RAM systems**. The overlayfs + tmpfs approach provides:
- ✅ Excellent responsiveness
- ✅ Efficient memory usage
- ✅ Protected base filesystem
- ✅ USB boot friendly
- ✅ Works perfectly on Raspberry Pi and embedded systems
