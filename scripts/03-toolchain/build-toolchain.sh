#!/bin/bash
# ============================================================
#  Phase 3: Build Cross-Compilation Toolchain
#  Order: binutils (pass1) → gcc (pass1) → headers → glibc → gcc (pass2)
# ============================================================

set -euo pipefail

LFS=${LFS:-/mnt/lfs}
SOURCES="$LFS/sources"
TOOLS="$LFS/tools"
LFS_TGT="x86_64-lfs-linux-gnu"
JOBS=${LFS_JOBS:-$(nproc)}

export PATH="$TOOLS/bin:$PATH"
export CONFIG_SITE="$LFS/usr/share/config.site"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

log()    { echo -e "${CYAN}[toolchain]${NC} $*"; }
ok()     { echo -e "${GREEN}  ✔ $*${NC}"; }
err()    { echo -e "${RED}  ✘ $*${NC}"; exit 1; }
step()   { echo -e "\n${BOLD}── $* ────────────────────────────${NC}"; }
unpack() {
  local archive
  archive=$(ls "$SOURCES/$1"*.tar.* 2>/dev/null | head -1)
  [[ -z "$archive" ]] && err "Source not found: $1 in $SOURCES"
  log "Unpacking $(basename "$archive")..."
  tar -xf "$archive" -C /tmp/lfs-build/
  # Return extracted dir name
  basename "$archive" .tar.xz 2>/dev/null || \
  basename "$archive" .tar.gz 2>/dev/null || \
  basename "$archive" .tar.bz2
}

# ── Setup ─────────────────────────────────────────────────────
[[ "$EUID" -eq 0 ]] || err "Must run as root"
mkdir -pv "$TOOLS" "$LFS/usr/"{bin,lib,sbin,include}
mkdir -pv /tmp/lfs-build
ln -sfv usr "$LFS/bin" 2>/dev/null || true
ln -sfv usr "$LFS/lib" 2>/dev/null || true
ln -sfv usr "$LFS/sbin" 2>/dev/null || true
ln -sfv lib "$LFS/lib64" 2>/dev/null || true

# ── Step 1: Binutils Pass 1 ──────────────────────────────────
step "Binutils-2.42 (Pass 1)"
cd /tmp/lfs-build
unpack "binutils"
BDIR=$(ls -d /tmp/lfs-build/binutils-*/ | head -1)
mkdir -v "$BDIR/build"
cd "$BDIR/build"
../configure \
  --prefix="$TOOLS" \
  --with-sysroot="$LFS" \
  --target="$LFS_TGT" \
  --disable-nls \
  --enable-gprofng=no \
  --disable-werror
make -j"$JOBS"
make install
ok "Binutils pass 1 done"

# ── Step 2: GCC Pass 1 ───────────────────────────────────────
step "GCC-13.2.0 (Pass 1 — C only)"
cd /tmp/lfs-build
unpack "gcc"
GCCDIR=$(ls -d /tmp/lfs-build/gcc-*/ | head -1)

# GCC needs mpfr, gmp, mpc inside its tree
cd "$GCCDIR"
tar -xf "$SOURCES"/mpfr-*.tar.xz && mv mpfr-*/ mpfr/
tar -xf "$SOURCES"/gmp-*.tar.xz  && mv gmp-*/  gmp/
tar -xf "$SOURCES"/mpc-*.tar.gz  && mv mpc-*/  mpc/

# Patch to use 64-bit default
sed -e '/m64=/s/lib64/lib/' -i gcc/config/i386/t-linux64

mkdir -v build && cd build
../configure \
  --target="$LFS_TGT" \
  --prefix="$TOOLS" \
  --with-glibc-version=2.39 \
  --with-sysroot="$LFS" \
  --with-newlib \
  --without-headers \
  --enable-default-pie \
  --enable-default-ssp \
  --disable-nls \
  --disable-shared \
  --disable-multilib \
  --disable-threads \
  --disable-libatomic \
  --disable-libgomp \
  --disable-libquadmath \
  --disable-libssp \
  --disable-libvtv \
  --disable-libstdcxx \
  --enable-languages=c,c++
make -j"$JOBS"
make install

# Generate limits.h
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  "$(dirname "$($LFS_TGT-gcc -print-libgcc-file-name)")/include/limits.h"
ok "GCC pass 1 done"

# ── Step 3: Linux Kernel Headers ─────────────────────────────
step "Linux Kernel Headers"
cd /tmp/lfs-build
unpack "linux"
LINUXDIR=$(ls -d /tmp/lfs-build/linux-*/ | head -1)
cd "$LINUXDIR"
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include "$LFS/usr/"
ok "Kernel headers installed"

# ── Step 4: Glibc ────────────────────────────────────────────
step "Glibc-2.39"
cd /tmp/lfs-build
unpack "glibc"
GLIBCDIR=$(ls -d /tmp/lfs-build/glibc-*/ | head -1)
cd "$GLIBCDIR"

# Required symlink for LSB compliance
case $(uname -m) in
  i?86) ln -sfv ld-linux.so.2 "$LFS/lib/ld-lsb.so.3" ;;
  x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3" ;;
esac

patch -Np1 -i "$SOURCES"/glibc-2.39-fhs-1.patch 2>/dev/null || \
  log "No glibc patch needed"

mkdir -v build && cd build
echo "rootsbindir=/usr/sbin" > configparms

../configure \
  --prefix=/usr \
  --host="$LFS_TGT" \
  --build="$(../scripts/config.guess)" \
  --enable-kernel=4.14 \
  --with-headers="$LFS/usr/include" \
  --disable-nscd \
  libc_cv_slibdir=/usr/lib

make -j"$JOBS"
make DESTDIR="$LFS" install

# Fix ldd path
sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"

# Sanity check
echo "Testing glibc..."
echo 'int main(){}' > /tmp/test.c
"$LFS_TGT-gcc" /tmp/test.c -o /tmp/test
readelf -l /tmp/test | grep -q "ld-linux" && ok "Glibc sanity check passed" || err "Glibc sanity check FAILED"
rm /tmp/test.c /tmp/test

ok "Glibc done"

# ── Step 5: Libstdc++ ─────────────────────────────────────────
step "Libstdc++ (from GCC tree)"
cd "$GCCDIR/build"
rm -rf *
../libstdc++-v3/configure \
  --host="$LFS_TGT" \
  --build="$(../config.guess)" \
  --prefix=/usr \
  --disable-multilib \
  --disable-nls \
  --disable-libstdcxx-pch \
  --with-gxx-include-dir="$TOOLS/$LFS_TGT/include/c++/13.2.0"
make -j"$JOBS"
make DESTDIR="$LFS" install
rm -v "$LFS/usr/lib/lib"{stdc++{,exp},supc++}.la
ok "Libstdc++ done"

# ── Cleanup ───────────────────────────────────────────────────
rm -rf /tmp/lfs-build/*
ok "Toolchain build complete!"
log "Cross-compiler: $TOOLS/bin/$LFS_TGT-gcc"
