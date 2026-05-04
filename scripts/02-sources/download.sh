#!/bin/bash
# ============================================================
#  Phase 2: Download All Source Packages
#  Downloads kernel, glibc, gcc, binutils, bash, coreutils...
# ============================================================

set -euo pipefail

LFS=${LFS:-/mnt/lfs}
SOURCES="$LFS/sources"
JOBS=$(nproc)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[sources]${NC} $*"; }
ok()   { echo -e "${GREEN}  ✔ $*${NC}"; }
err()  { echo -e "${RED}  ✘ $*${NC}"; exit 1; }

mkdir -pv "$SOURCES"
chmod -v a+wt "$SOURCES"

# ── Package list: name | url ──────────────────────────────────
declare -A PACKAGES=(
  ["linux-6.6.30.tar.xz"]="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.30.tar.xz"
  ["glibc-2.39.tar.xz"]="https://ftp.gnu.org/gnu/glibc/glibc-2.39.tar.xz"
  ["gcc-13.2.0.tar.xz"]="https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz"
  ["binutils-2.42.tar.xz"]="https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.xz"
  ["bash-5.2.21.tar.gz"]="https://ftp.gnu.org/gnu/bash/bash-5.2.21.tar.gz"
  ["coreutils-9.4.tar.xz"]="https://ftp.gnu.org/gnu/coreutils/coreutils-9.4.tar.xz"
  ["util-linux-2.39.3.tar.xz"]="https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.39/util-linux-2.39.3.tar.xz"
  ["make-4.4.1.tar.gz"]="https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz"
  ["grep-3.11.tar.xz"]="https://ftp.gnu.org/gnu/grep/grep-3.11.tar.xz"
  ["sed-4.9.tar.xz"]="https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz"
  ["gzip-1.13.tar.xz"]="https://ftp.gnu.org/gnu/gzip/gzip-1.13.tar.xz"
  ["tar-1.35.tar.xz"]="https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz"
  ["xz-5.4.6.tar.xz"]="https://github.com/tukaani-project/xz/releases/download/v5.4.6/xz-5.4.6.tar.xz"
  ["zlib-1.3.1.tar.gz"]="https://zlib.net/zlib-1.3.1.tar.gz"
  ["bzip2-1.0.8.tar.gz"]="https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz"
  ["ncurses-6.4.tar.gz"]="https://ftp.gnu.org/gnu/ncurses/ncurses-6.4.tar.gz"
  ["readline-8.2.tar.gz"]="https://ftp.gnu.org/gnu/readline/readline-8.2.tar.gz"
  ["m4-1.4.19.tar.xz"]="https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz"
  ["gawk-5.3.0.tar.xz"]="https://ftp.gnu.org/gnu/gawk/gawk-5.3.0.tar.xz"
  ["file-5.45.tar.gz"]="https://astron.com/pub/file/file-5.45.tar.gz"
  ["findutils-4.9.0.tar.xz"]="https://ftp.gnu.org/gnu/findutils/findutils-4.9.0.tar.xz"
  ["diffutils-3.10.tar.xz"]="https://ftp.gnu.org/gnu/diffutils/diffutils-3.10.tar.xz"
  ["patch-2.7.6.tar.xz"]="https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz"
  ["texinfo-7.1.tar.xz"]="https://ftp.gnu.org/gnu/texinfo/texinfo-7.1.tar.xz"
  ["shadow-4.14.2.tar.xz"]="https://github.com/shadow-maint/shadow/releases/download/4.14.2/shadow-4.14.2.tar.xz"
  ["sysvinit-3.08.tar.xz"]="https://github.com/slicer69/sysvinit/releases/download/3.08/sysvinit-3.08.tar.xz"
  ["eudev-3.2.14.tar.gz"]="https://github.com/eudev-project/eudev/releases/download/v3.2.14/eudev-3.2.14.tar.gz"
  ["openssl-3.3.0.tar.gz"]="https://www.openssl.org/source/openssl-3.3.0.tar.gz"
  ["grub-2.12.tar.xz"]="https://ftp.gnu.org/gnu/grub/grub-2.12.tar.xz"
  ["mpfr-4.2.1.tar.xz"]="https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz"
  ["gmp-6.3.0.tar.xz"]="https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz"
  ["mpc-1.3.1.tar.gz"]="https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz"
)

TOTAL=${#PACKAGES[@]}
DONE=0; SKIPPED=0; FAILED=0

log "Downloading $TOTAL source packages to $SOURCES"
echo ""

download_pkg() {
  local filename=$1
  local url=$2
  local dest="$SOURCES/$filename"

  if [[ -f "$dest" ]]; then
    echo -e "  ${YELLOW}↷${NC} Skipping (exists): $filename"
    ((SKIPPED++))
    return
  fi

  echo -ne "  ${CYAN}↓${NC} Downloading: ${BOLD}$filename${NC}..."
  if wget -q --show-progress --timeout=60 --tries=3 \
       -O "$dest" "$url" 2>&1 | tail -1; then
    ok " done"
    ((DONE++))
  else
    rm -f "$dest"
    echo -e " ${RED}FAILED${NC}"
    ((FAILED++))
  fi
}

# Download all packages
for pkg in "${!PACKAGES[@]}"; do
  download_pkg "$pkg" "${PACKAGES[$pkg]}"
done

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════"
log "Download Summary"
echo "  Downloaded : $DONE"
echo "  Skipped    : $SKIPPED (already present)"
echo "  Failed     : $FAILED"
echo "══════════════════════════════════════"

[[ "$FAILED" -gt 0 ]] && err "$FAILED packages failed to download!"
ok "All sources ready in $SOURCES"

# ── Create checksums ─────────────────────────────────────────
log "Generating checksums..."
cd "$SOURCES"
sha256sum ./*.tar.* > sha256sums.txt
ok "Checksums saved to $SOURCES/sha256sums.txt"
