# LFS-Custom — Linux From Scratch Build System

A complete automated build system for Linux From Scratch 12.1.
Builds a minimal, bootable Linux system entirely from source.

## Quick Start

```bash
# 1. Check host requirements
sudo LFS_DISK=/dev/sdb ./build.sh check

# 2. Build everything (takes 4-12 hours)
sudo LFS_DISK=/dev/sdb ./build.sh all

# Or build phase by phase:
sudo LFS_DISK=/dev/sdb ./build.sh partition
sudo LFS_DISK=/dev/sdb ./build.sh sources
sudo LFS_DISK=/dev/sdb ./build.sh toolchain
sudo LFS_DISK=/dev/sdb ./build.sh kernel
sudo LFS_DISK=/dev/sdb ./build.sh rootfs
sudo LFS_DISK=/dev/sdb ./build.sh boot
```

## Configuration

Edit `build.sh` variables:

| Variable       | Default        | Description              |
|----------------|----------------|--------------------------|
| `LFS`          | `/mnt/lfs`     | Mount point              |
| `LFS_DISK`     | `/dev/sdb`     | Target disk              |
| `LFS_JOBS`     | `$(nproc)`     | Parallel build jobs      |
| `KERNEL_VERSION`| `6.6.30`      | Linux kernel version     |
| `GLIBC_VERSION`| `2.39`         | GNU C Library version    |
| `GCC_VERSION`  | `13.2.0`       | GCC version              |

## Build Phases

```
Phase 0: check      Host system requirements check
Phase 1: partition  Create & format disk partitions
Phase 2: sources    Download all source packages
Phase 3: toolchain  Build cross-compilation toolchain
Phase 4: kernel     Compile Linux kernel 6.6.30
Phase 5: rootfs     Build root filesystem in chroot
Phase 6: boot       Install GRUB bootloader
```

## Disk Layout

```
/dev/sdX1  512MB   EFI System Partition (FAT32) → /boot/efi
/dev/sdX2  2GB     Swap
/dev/sdX3  rest    Root filesystem (ext4)        → /
```

## Host Requirements

- Ubuntu 20.04+ / Debian 11+ / Fedora 36+ (or any modern distro)
- GCC 6.2+, Glibc 2.11+, Bash 3.2+
- 30GB+ free disk space on target disk
- 2GB+ RAM (8GB+ recommended)
- Internet connection for phase 2

## Kernel

Built with:
- `x86_64_defconfig` as base
- EFI/UEFI boot support
- AHCI/SATA, VirtIO, E1000 drivers
- ext4, XFS, Btrfs filesystem support
- Security hardening (ASLR, stack protector, SLAB randomization)

Custom config at: `config/kernel.config`

## Packages Included

| Package       | Version  |
|---------------|----------|
| Linux kernel  | 6.6.30   |
| Glibc         | 2.39     |
| GCC           | 13.2.0   |
| Binutils      | 2.42     |
| Bash          | 5.2.21   |
| Coreutils     | 9.4      |
| Util-linux    | 2.39.3   |
| Ncurses       | 6.4      |
| Shadow        | 4.14.2   |
| Sysvinit      | 3.08     |
| OpenSSL       | 3.3.0    |
| GRUB          | 2.12     |
| + 20 more...  |          |

## Logs

Build logs saved to `/var/log/lfs-build-YYYYMMDD-HHMMSS.log`

## After Install

```bash
# Set root password (IMPORTANT!)
passwd root

# Set timezone
ln -sfv /usr/share/zoneinfo/Region/City /etc/localtime

# Edit /etc/fstab with correct UUIDs
blkid  # find UUIDs
vim /etc/fstab

# Reboot
reboot
```

## Reference

- [Linux From Scratch Book](https://www.linuxfromscratch.org/lfs/view/stable/)
- [LFS Errata](https://www.linuxfromscratch.org/lfs/errata/12.1/)
