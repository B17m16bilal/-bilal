#!/bin/bash
# ============================================================
#  Phase 4: Compile Linux Kernel 6.6.30
# ============================================================

set -euo pipefail

LFS=${LFS:-/mnt/lfs}
SOURCES="$LFS/sources"
JOBS=${LFS_JOBS:-$(nproc)}
KERNEL_VERSION="6.6.30"
BUILD_DIR="/tmp/linux-build"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[kernel]${NC} $*"; }
ok()   { echo -e "${GREEN}  ✔ $*${NC}"; }
err()  { echo -e "${RED}  ✘ $*${NC}"; exit 1; }

[[ "$EUID" -eq 0 ]] || err "Must run as root"

# ── Extract ───────────────────────────────────────────────────
log "Extracting kernel $KERNEL_VERSION..."
mkdir -p "$BUILD_DIR"
tar -xf "$SOURCES/linux-${KERNEL_VERSION}.tar.xz" -C "$BUILD_DIR"
cd "$BUILD_DIR/linux-${KERNEL_VERSION}"
ok "Extracted"

# ── Clean ─────────────────────────────────────────────────────
log "Running mrproper..."
make mrproper

# ── Configure ────────────────────────────────────────────────
log "Configuring kernel (defconfig + LFS tweaks)..."

# Start with x86_64 defconfig as base
make x86_64_defconfig

# ── Essential LFS config options ─────────────────────────────
# Written via script (no menuconfig needed)
cat >> .config << 'KCONFIG'
# General
CONFIG_LOCALVERSION="-lfs"
CONFIG_DEFAULT_HOSTNAME="lfs"

# Filesystems — required
CONFIG_EXT4_FS=y
CONFIG_EXT4_USE_FOR_EXT2=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_TMPFS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y

# Block devices
CONFIG_BLK_DEV_SD=y
CONFIG_ATA=y
CONFIG_ATA_PIIX=y
CONFIG_SATA_AHCI=y

# Network
CONFIG_NET=y
CONFIG_INET=y
CONFIG_PACKET=y
CONFIG_UNIX=y
CONFIG_E1000=y
CONFIG_E1000E=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_PCI=y

# EFI/UEFI
CONFIG_EFI=y
CONFIG_EFI_STUB=y

# TTY / Serial console
CONFIG_TTY=y
CONFIG_VT=y
CONFIG_VT_CONSOLE=y
CONFIG_HW_CONSOLE=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y

# Input
CONFIG_INPUT=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_KEYBOARD_ATKBD=y
CONFIG_INPUT_MOUSE=y
CONFIG_MOUSE_PS2=y

# USB
CONFIG_USB_SUPPORT=y
CONFIG_USB=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_STORAGE=y

# Compression
CONFIG_KERNEL_XZ=y
CONFIG_RD_XZ=y

# Initramfs
CONFIG_BLK_DEV_INITRD=y
CONFIG_INITRAMFS_SOURCE=""

# POSIX/Security
CONFIG_MULTIUSER=y
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
CONFIG_FUTEX=y
CONFIG_EPOLL=y
CONFIG_INOTIFY_USER=y
CONFIG_SIGNALFD=y
CONFIG_TIMERFD=y
CONFIG_EVENTFD=y
CONFIG_SHMEM=y
CONFIG_AIO=y
KCONFIG

# Resolve any config dependencies
make olddefconfig
ok "Kernel configured"

# ── Build ─────────────────────────────────────────────────────
log "Compiling kernel with $JOBS jobs... (this takes 10-40 min)"
time make -j"$JOBS" 2>&1 | tee /var/log/kernel-build.log | \
  grep --line-buffered -E "(CC|LD|AR|LINK|Error|error:)" || true
ok "Kernel compiled"

# ── Build modules ────────────────────────────────────────────
log "Building modules..."
make -j"$JOBS" modules
ok "Modules built"

# ── Install ───────────────────────────────────────────────────
log "Installing kernel..."
make INSTALL_PATH="$LFS/boot" install
ok "Kernel installed to $LFS/boot"

log "Installing modules..."
make INSTALL_MOD_PATH="$LFS" modules_install
ok "Modules installed to $LFS/lib/modules"

# ── Copy config ───────────────────────────────────────────────
cp -v .config "$LFS/boot/config-${KERNEL_VERSION}-lfs"
cp -v System.map "$LFS/boot/System.map-${KERNEL_VERSION}-lfs"

# ── Show results ─────────────────────────────────────────────
log "Kernel files in $LFS/boot:"
ls -lh "$LFS/boot/"

VMLINUZ=$(ls "$LFS/boot/vmlinuz-"* 2>/dev/null | head -1)
[[ -n "$VMLINUZ" ]] && ok "Kernel image: $(basename "$VMLINUZ") ($(du -h "$VMLINUZ" | cut -f1))"

ok "Kernel build complete!"

# ── Cleanup ───────────────────────────────────────────────────
rm -rf "$BUILD_DIR"
log "Build directory cleaned"
