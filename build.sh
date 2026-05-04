#!/bin/bash
# ============================================================
#  LFS-CUSTOM - Linux From Scratch Build System
#  Version: 1.0.0
#  Usage: sudo ./build.sh [phase]
#  Phases: all | check | partition | sources | toolchain | kernel | rootfs | boot
# ============================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Config ───────────────────────────────────────────────────
export LFS=/mnt/lfs
export LFS_DISK=${LFS_DISK:-/dev/sdb}      # Change to your disk
export LFS_JOBS=$(nproc)
export LFS_VERSION="1.0.0"
export KERNEL_VERSION="6.6.30"
export GLIBC_VERSION="2.39"
export GCC_VERSION="13.2.0"
export BINUTILS_VERSION="2.42"
export BASH_VERSION="5.2.21"

# ── Logging ──────────────────────────────────────────────────
LOG_FILE="/var/log/lfs-build-$(date +%Y%m%d-%H%M%S).log"
mkdir -p /var/log

log()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${GREEN}  ✔ $*${NC}" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}  ⚠ $*${NC}" | tee -a "$LOG_FILE"; }
err()  { echo -e "${RED}  ✘ $*${NC}" | tee -a "$LOG_FILE"; exit 1; }
header() {
  echo "" | tee -a "$LOG_FILE"
  echo -e "${BOLD}${BLUE}══════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
  echo -e "${BOLD}${BLUE}  $*${NC}" | tee -a "$LOG_FILE"
  echo -e "${BOLD}${BLUE}══════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
}

# ── Banner ───────────────────────────────────────────────────
print_banner() {
cat << 'EOF'
  ██╗     ███████╗███████╗
  ██║     ██╔════╝██╔════╝
  ██║     █████╗  ███████╗
  ██║     ██╔══╝  ╚════██║
  ███████╗██║     ███████║
  ╚══════╝╚═╝     ╚══════╝
  Linux From Scratch — Custom Build System v1.0.0
EOF
}

# ── Phase Router ─────────────────────────────────────────────
PHASE="${1:-all}"

print_banner
log "Starting LFS build — phase: ${BOLD}$PHASE${NC}"
log "Target disk: $LFS_DISK | Mount: $LFS | Jobs: $LFS_JOBS"
echo ""

case "$PHASE" in
  all)
    bash scripts/00-host-check/check.sh
    bash scripts/01-partitions/partition.sh
    bash scripts/02-sources/download.sh
    bash scripts/03-toolchain/build-toolchain.sh
    bash scripts/04-kernel/build-kernel.sh
    bash scripts/05-rootfs/build-rootfs.sh
    bash scripts/06-bootloader/install-grub.sh
    ;;
  check)     bash scripts/00-host-check/check.sh ;;
  partition) bash scripts/01-partitions/partition.sh ;;
  sources)   bash scripts/02-sources/download.sh ;;
  toolchain) bash scripts/03-toolchain/build-toolchain.sh ;;
  kernel)    bash scripts/04-kernel/build-kernel.sh ;;
  rootfs)    bash scripts/05-rootfs/build-rootfs.sh ;;
  boot)      bash scripts/06-bootloader/install-grub.sh ;;
  *)         err "Unknown phase: $PHASE. Use: all|check|partition|sources|toolchain|kernel|rootfs|boot" ;;
esac

ok "Build phase '$PHASE' completed successfully!"
log "Log saved to: $LOG_FILE"
