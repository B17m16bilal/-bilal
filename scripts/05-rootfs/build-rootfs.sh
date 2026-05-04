#!/bin/bash
# ============================================================
#  Phase 5: Build Root Filesystem (chroot environment)
#  Builds: bash, coreutils, util-linux, shadow, sysvinit...
#  Then enters chroot to configure the system
# ============================================================

set -euo pipefail

LFS=${LFS:-/mnt/lfs}
SOURCES="$LFS/sources"
JOBS=${LFS_JOBS:-$(nproc)}
TOOLS="$LFS/tools"
LFS_TGT="x86_64-lfs-linux-gnu"

export PATH="$TOOLS/bin:/usr/bin:/bin"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

log()    { echo -e "${CYAN}[rootfs]${NC} $*"; }
ok()     { echo -e "${GREEN}  ✔ $*${NC}"; }
err()    { echo -e "${RED}  ✘ $*${NC}"; exit 1; }
step()   { echo -e "\n${BOLD}── Building: $* ────────────────────────${NC}"; }

[[ "$EUID" -eq 0 ]] || err "Must run as root"
[[ -d "$LFS" ]] || err "$LFS does not exist — run partition.sh first"

# ── Directory structure ───────────────────────────────────────
log "Creating LFS directory hierarchy..."
mkdir -pv "$LFS"/{boot,dev,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
mkdir -pv "$LFS"/{media/{floppy,cdrom},srv,var}
install -dv -m 0750 "$LFS/root"
install -dv -m 1777 "$LFS/tmp" "$LFS/var/tmp"
mkdir -pv "$LFS/usr/"{,local/}{include,src}
mkdir -pv "$LFS/usr/local/"{bin,lib,sbin}
mkdir -pv "$LFS/usr"/{bin,lib,sbin}
mkdir -pv "$LFS/var/"{cache,local,log,mail,opt,spool}
mkdir -pv "$LFS/var/lib/"{color,misc,locate,hwclock}

# Compatibility symlinks
for dir in bin lib sbin; do
  ln -sfv "usr/$dir" "$LFS/$dir" 2>/dev/null || true
done
ln -sfv "usr/lib" "$LFS/lib64" 2>/dev/null || true
ok "Directory hierarchy created"

# ── Essential files ───────────────────────────────────────────
log "Creating essential system files..."

# /etc/hosts
cat > "$LFS/etc/hosts" << 'EOF'
127.0.0.1  localhost
127.0.1.1  lfs
::1        localhost ip6-localhost ip6-loopback
EOF

# /etc/passwd
cat > "$LFS/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
daemon:x:6:6:Daemon User:/dev/null:/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/bin/false
EOF

# /etc/group
cat > "$LFS/etc/group" << 'EOF'
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF

# /etc/fstab (template)
cat > "$LFS/etc/fstab" << 'EOF'
# /etc/fstab — edit UUIDs after installation
# UUID=<root-uuid>  /          ext4   defaults,noatime  0 1
# UUID=<efi-uuid>   /boot/efi  vfat   defaults          0 2
# UUID=<swap-uuid>  none       swap   sw                0 0
tmpfs             /tmp       tmpfs  defaults,size=512M  0 0
EOF

# /etc/hostname
echo "lfs" > "$LFS/etc/hostname"

# /etc/shells
cat > "$LFS/etc/shells" << 'EOF'
/bin/sh
/bin/bash
EOF

# /etc/profile
cat > "$LFS/etc/profile" << 'EOF'
# /etc/profile — LFS system-wide environment
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
export TERM=xterm-256color
export EDITOR=vi
export PAGER=more
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Set locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# History
export HISTSIZE=1000
export HISTFILESIZE=2000

# Source user profile
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
EOF

# /etc/issue and /etc/os-release
cat > "$LFS/etc/issue" << 'EOF'

  ██╗     ███████╗███████╗
  ██║     ██╔════╝██╔════╝
  ██║     █████╗  ███████╗
  ██║     ██╔══╝  ╚════██║
  ███████╗██║     ███████║

  Linux From Scratch 12.1 — Kernel \r (\l)

EOF

cat > "$LFS/etc/os-release" << 'EOF'
NAME="LFS"
VERSION="12.1"
ID=lfs
PRETTY_NAME="Linux From Scratch 12.1"
VERSION_CODENAME="custom"
HOME_URL="https://www.linuxfromscratch.org/"
EOF

ok "System configuration files created"

# ── Mount virtual filesystems ─────────────────────────────────
log "Mounting virtual filesystems..."
mount -v --bind /dev      "$LFS/dev"
mount -v --bind /dev/pts  "$LFS/dev/pts"
mount -vt proc proc       "$LFS/proc"
mount -vt sysfs sysfs     "$LFS/sys"
mount -vt tmpfs tmpfs     "$LFS/run"

# Device nodes
if [ -h "$LFS/dev/shm" ]; then
  mkdir -pv "$LFS/$(readlink "$LFS/dev/shm")"
else
  mount -t tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"
fi
ok "Virtual filesystems mounted"

# ── Build packages inside chroot ─────────────────────────────
log "Entering chroot to build core packages..."

chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM="$TERM" PS1='(lfs chroot) \u:\w\$ ' \
  PATH=/usr/bin:/usr/sbin \
  /bin/bash --login << 'CHROOT_SCRIPT'

set -euo pipefail
JOBS=$(nproc)
SOURCES=/sources

echo "═══════════════════════════════════════════"
echo "  Inside chroot — building LFS packages"
echo "═══════════════════════════════════════════"

build_pkg() {
  local name=$1
  local archive
  archive=$(ls "$SOURCES/$name"-*.tar.* 2>/dev/null | head -1)
  [ -z "$archive" ] && { echo "  ⚠ Not found: $name"; return; }

  echo "── Building: $(basename "$archive") ──"
  local tmpdir="/tmp/build-$name"
  mkdir -p "$tmpdir"
  tar -xf "$archive" -C "$tmpdir"
  local srcdir
  srcdir=$(ls -d "$tmpdir"/*/ | head -1)
  cd "$srcdir"
  export PKG_NAME="$name"
  build_"${name//-/_}" 2>&1 | tail -5
  cd /
  rm -rf "$tmpdir"
  echo "  ✔ $name done"
}

# ── m4 ────────────────────────────────────────────────────────
build_m4() {
  ./configure --prefix=/usr
  make -j"$JOBS" && make install
}

# ── ncurses ───────────────────────────────────────────────────
build_ncurses() {
  ./configure --prefix=/usr --mandir=/usr/share/man \
    --with-shared --without-debug --without-normal \
    --with-cxx-shared --enable-pc-files \
    --enable-widec
  make -j"$JOBS" && make install
  # Fix non-wide char compat
  for lib in ncurses form panel menu; do
    echo "INPUT(-l${lib}w)" > "/usr/lib/lib${lib}.so"
    ln -sfv "${lib}w.pc" "/usr/lib/pkgconfig/${lib}.pc"
  done
  ln -sfv libncursesw.so /usr/lib/libcurses.so
}

# ── bash ─────────────────────────────────────────────────────
build_bash() {
  ./configure --prefix=/usr \
    --without-bash-malloc --with-installed-readline
  make -j"$JOBS" && make install
  ln -sfv bash /usr/bin/sh
}

# ── coreutils ────────────────────────────────────────────────
build_coreutils() {
  ./configure --prefix=/usr \
    --enable-no-install-program=kill,uptime
  make -j"$JOBS" && make install
  mv -v /usr/bin/chroot /usr/sbin/
}

# ── grep ─────────────────────────────────────────────────────
build_grep() {
  sed -i "s/echo/#echo/" src/egrep.sh
  ./configure --prefix=/usr
  make -j"$JOBS" && make install
}

# ── sed ──────────────────────────────────────────────────────
build_sed() {
  ./configure --prefix=/usr
  make -j"$JOBS" && make install
}

# ── gzip ─────────────────────────────────────────────────────
build_gzip() {
  ./configure --prefix=/usr
  make -j"$JOBS" && make install
}

# ── tar ──────────────────────────────────────────────────────
build_tar() {
  ./configure --prefix=/usr
  make -j"$JOBS" && make install
}

# ── find ─────────────────────────────────────────────────────
build_findutils() {
  ./configure --prefix=/usr \
    --localstatedir=/var/lib/locate
  make -j"$JOBS" && make install
}

# ── shadow ───────────────────────────────────────────────────
build_shadow() {
  sed -i 's/groups$(EXEEXT) //' src/Makefile.in
  ./configure --sysconfdir=/etc --disable-static \
    --with-group-name-max-length=32
  make -j"$JOBS" && make exec_prefix=/usr install
  # Set root password to empty (change after install!)
  passwd -d root
  # Enable shadow passwords
  pwconv
  grpconv
}

# ── sysvinit ─────────────────────────────────────────────────
build_sysvinit() {
  make -j"$JOBS"
  make install
}

# ── util-linux ───────────────────────────────────────────────
build_util_linux() {
  ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime \
    --libdir=/usr/lib \
    --bindir=/usr/bin \
    --sbindir=/usr/sbin \
    --disable-chfn-chsh \
    --disable-login \
    --disable-nologin \
    --disable-su \
    --disable-setpriv \
    --disable-runuser \
    --disable-pylibmount \
    --disable-static \
    --without-python
  make -j"$JOBS" && make install
}

# ── Run builds ───────────────────────────────────────────────
for pkg in m4 ncurses bash coreutils grep sed gzip tar findutils shadow sysvinit util-linux; do
  build_pkg "$pkg"
done

# ── Final system config ──────────────────────────────────────
echo ""
echo "── Finalizing system configuration ──"

# Set timezone (UTC default)
ln -sfv /usr/share/zoneinfo/UTC /etc/localtime

# /etc/inputrc
cat > /etc/inputrc << 'EOF'
set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none
"\eOd": backward-word
"\eOc": forward-word
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert
"\eOH": beginning-of-line
"\eOF": end-of-line
"\e[H": beginning-of-line
"\e[F": end-of-line
EOF

# Logging dirs
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

echo "  ✔ System configuration complete"
echo ""
echo "═══════════════════════════════════════════"
echo "  chroot build complete!"
echo "═══════════════════════════════════════════"
CHROOT_SCRIPT

ok "Root filesystem build complete!"

# ── Unmount virtual filesystems ───────────────────────────────
log "Unmounting virtual filesystems..."
umount "$LFS/dev/pts"
umount "$LFS/dev/shm" 2>/dev/null || true
umount "$LFS/dev"
umount "$LFS/run"
umount "$LFS/proc"
umount "$LFS/sys"
ok "Virtual filesystems unmounted"
