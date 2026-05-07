#!/usr/bin/env bash
# ============================================================
#  ██████╗ ██╗██╗      █████╗ ██╗      ██████╗ ███████╗
#  ██╔══██╗██║██║     ██╔══██╗██║     ██╔═══██╗██╔════╝
#  ██████╔╝██║██║     ███████║██║     ██║   ██║███████╗
#  ██╔══██╗██║██║     ██╔══██║██║     ██║   ██║╚════██║
#  ██████╔╝██║███████╗██║  ██║███████╗╚██████╔╝███████║
#  ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚══════╝
#
#  Bilal OS — Live ISO Builder (Debian-based)
#  Version : 1.0.0
#  Author  : Bilal OS Project
#  License : MIT
# ============================================================

set -euo pipefail

# ─── COLORS ──────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';   YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';    WHITE='\033[1;37m'
BOLD='\033[1m';      RESET='\033[0m'

# ─── CONFIGURATION ───────────────────────────────────────────
OS_NAME="Bilal OS"
OS_VERSION="1.0"
OS_CODENAME="Horizon"
DEBIAN_SUITE="bookworm"          # Debian 12
ARCH="amd64"
WORK_DIR="$(pwd)/bilal-os-build"
OUTPUT_DIR="$(pwd)/bilal-os-output"
ISO_NAME="bilal-os-${OS_VERSION}-${ARCH}.iso"
MIRROR="http://deb.debian.org/debian"
TIMEZONE="Asia/Riyadh"
LOCALE="ar_SA.UTF-8"
HOSTNAME="bilal-os"
USERNAME="bilal"
PASSWORD="bilal123"

# ─── PACKAGES ────────────────────────────────────────────────
# Core system packages
CORE_PACKAGES=(
    linux-image-amd64
    live-boot
    live-config
    live-config-systemd
    systemd-sysv
    grub-efi-amd64
    grub-pc-bin
    grub2-common
    syslinux
    syslinux-common
    isolinux
    efibootmgr
)

# Desktop environment (XFCE — lightweight & beautiful)
DESKTOP_PACKAGES=(
    xfce4
    xfce4-goodies
    xfce4-terminal
    xfce4-screenshooter
    lightdm
    lightdm-gtk-greeter
    lightdm-gtk-greeter-settings
    xorg
    xinit
    x11-xserver-utils
)

# Essential applications
APP_PACKAGES=(
    firefox-esr
    thunar
    mousepad
    ristretto
    evince
    vlc
    file-roller
    gparted
    network-manager
    network-manager-gnome
    nm-tray
    blueman
    pulseaudio
    pavucontrol
    fonts-noto
    fonts-noto-cjk
    fonts-noto-color-emoji
    fonts-liberation
    fonts-dejavu
)

# System utilities
UTIL_PACKAGES=(
    bash-completion
    curl
    wget
    git
    nano
    vim
    htop
    neofetch
    sudo
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
    zip
    unzip
    p7zip-full
    ntfs-3g
    dosfstools
    os-prober
    firmware-linux-free
    firmware-linux-nonfree
    firmware-iwlwifi
    firmware-realtek
    firmware-atheros
)

# ─── HELPER FUNCTIONS ────────────────────────────────────────
banner() {
    clear
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║                                                      ║"
    echo "  ║          ██████╗ ██╗██╗      █████╗ ██╗             ║"
    echo "  ║          ██╔══██╗██║██║     ██╔══██╗██║             ║"
    echo "  ║          ██████╔╝██║██║     ███████║██║             ║"
    echo "  ║          ██╔══██╗██║██║     ██╔══██║██║             ║"
    echo "  ║          ██████╔╝██║███████╗██║  ██║███████╗        ║"
    echo "  ║          ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝        ║"
    echo "  ║                                                      ║"
    echo "  ║         OS Builder v${OS_VERSION} — ${OS_CODENAME} Edition              ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

log()     { echo -e "${GREEN}[✓]${RESET} ${WHITE}$*${RESET}"; }
info()    { echo -e "${CYAN}[i]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━${RESET}\n"; }
progress(){ echo -e "${YELLOW}[→]${RESET} $*..."; }

# ─── PRE-FLIGHT CHECKS ───────────────────────────────────────
check_requirements() {
    step "Checking Requirements"

    [[ $EUID -eq 0 ]] || error "This script must be run as root. Use: sudo $0"

    local tools=(debootstrap lb live-build xorriso squashfs-tools \
                 grub-efi-amd64-bin grub-pc-bin mksquashfs)
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Installing missing tools: ${missing[*]}"
        apt-get update -qq
        apt-get install -y --no-install-recommends \
            debootstrap live-build xorriso squashfs-tools \
            grub-efi-amd64-bin grub-pc-bin syslinux \
            syslinux-common isolinux genisoimage dosfstools
    fi

    # Check disk space (need at least 10 GB)
    local free_space
    free_space=$(df -BG "$(pwd)" | awk 'NR==2{print $4}' | tr -d 'G')
    [[ $free_space -ge 10 ]] || \
        error "Need at least 10 GB free. Only ${free_space}G available."

    log "All requirements satisfied"
}

# ─── SETUP DIRECTORIES ───────────────────────────────────────
setup_directories() {
    step "Setting Up Build Environment"

    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"/{chroot,binary/{boot/grub,isolinux,live},output}
    mkdir -p "$OUTPUT_DIR"

    log "Build directories created at: $WORK_DIR"
}

# ─── BOOTSTRAP BASE SYSTEM ───────────────────────────────────
bootstrap_system() {
    step "Bootstrapping Debian ${DEBIAN_SUITE}"
    progress "Downloading base system (this may take 5-10 minutes)"

    debootstrap \
        --arch="$ARCH" \
        --include="$(IFS=,; echo "${CORE_PACKAGES[*]}")" \
        "$DEBIAN_SUITE" \
        "$WORK_DIR/chroot" \
        "$MIRROR" \
        || error "debootstrap failed"

    log "Base system bootstrapped successfully"
}

# ─── CONFIGURE CHROOT ────────────────────────────────────────
configure_chroot() {
    step "Configuring System Inside Chroot"

    # Mount virtual filesystems
    mount --bind /dev     "$WORK_DIR/chroot/dev"
    mount --bind /dev/pts "$WORK_DIR/chroot/dev/pts"
    mount --bind /proc    "$WORK_DIR/chroot/proc"
    mount --bind /sys     "$WORK_DIR/chroot/sys"

    # Configure APT sources
    cat > "$WORK_DIR/chroot/etc/apt/sources.list" << EOF
deb $MIRROR $DEBIAN_SUITE main contrib non-free non-free-firmware
deb $MIRROR ${DEBIAN_SUITE}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${DEBIAN_SUITE}-security main contrib non-free non-free-firmware
EOF

    # Run configuration inside chroot
    chroot "$WORK_DIR/chroot" /bin/bash << CHROOT_EOF
set -e

# Basic system settings
export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

# Update package lists
apt-get update -qq

# Set hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME}
::1         localhost ip6-localhost ip6-loopback
HOSTS

# Set locale
apt-get install -y --no-install-recommends locales
echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG="${LOCALE}"

# Set timezone
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
echo "${TIMEZONE}" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Install desktop environment
apt-get install -y --no-install-recommends \
    xfce4 xfce4-goodies xfce4-terminal xfce4-screenshooter \
    lightdm lightdm-gtk-greeter xorg xinit x11-xserver-utils \
    xfce4-power-manager xfce4-notifyd xfce4-clipman

# Install applications
apt-get install -y --no-install-recommends \
    firefox-esr thunar mousepad ristretto evince vlc \
    file-roller gparted network-manager network-manager-gnome \
    pulseaudio pavucontrol \
    fonts-noto fonts-noto-color-emoji fonts-liberation fonts-dejavu

# Install utilities
apt-get install -y --no-install-recommends \
    bash-completion curl wget git nano vim htop neofetch \
    sudo apt-transport-https ca-certificates gnupg \
    zip unzip p7zip-full ntfs-3g dosfstools os-prober \
    firmware-linux-free

# Create live user
useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev "${USERNAME}"
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "root:root" | chpasswd

# Configure sudo without password for live user
echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}
chmod 440 /etc/sudoers.d/${USERNAME}

# Enable services
systemctl enable lightdm NetworkManager bluetooth || true

# Configure LightDM autologin
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/01-autologin.conf << LDM
[Seat:*]
autologin-user=${USERNAME}
autologin-user-timeout=0
user-session=xfce
LDM

CHROOT_EOF

    log "System configured successfully"
}

# ─── CUSTOMIZE BILAL OS ──────────────────────────────────────
customize_bilal_os() {
    step "Applying Bilal OS Customizations"

    # ── OS Release Info ──
    cat > "$WORK_DIR/chroot/etc/os-release" << EOF
PRETTY_NAME="Bilal OS ${OS_VERSION} (${OS_CODENAME})"
NAME="Bilal OS"
VERSION_ID="${OS_VERSION}"
VERSION="$OS_VERSION (${OS_CODENAME})"
VERSION_CODENAME=${OS_CODENAME,,}
ID=bilalos
ID_LIKE=debian
HOME_URL="https://bilalos.github.io"
SUPPORT_URL="https://bilalos.github.io/support"
BUG_REPORT_URL="https://bilalos.github.io/bugs"
EOF

    # ── Issue / Login Banner ──
    cat > "$WORK_DIR/chroot/etc/issue" << 'EOF'

  ██████╗ ██╗██╗      █████╗ ██╗       ██████╗ ███████╗
  ██╔══██╗██║██║     ██╔══██╗██║      ██╔═══██╗██╔════╝
  ██████╔╝██║██║     ███████║██║      ██║   ██║███████╗
  ██╔══██╗██║██║     ██╔══██║██║      ██║   ██║╚════██║
  ██████╔╝██║███████╗██║  ██║███████╗ ╚██████╔╝███████║
  ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝  ╚═════╝ ╚══════╝

  Welcome to Bilal OS — Horizon Edition
  Kernel: \r | Arch: \m | Host: \n

EOF

    # ── Neofetch Config ──
    mkdir -p "$WORK_DIR/chroot/home/${USERNAME}/.config/neofetch"
    cat > "$WORK_DIR/chroot/home/${USERNAME}/.config/neofetch/config.conf" << 'EOF'
print_info() {
    prin "$(color 6)  ██████╗ ██╗██╗      █████╗ ██╗"
    prin "$(color 6)  ██╔══██╗██║██║     ██╔══██╗██║"
    prin "$(color 6)  ██████╔╝██║██║     ███████║██║"
    prin "$(color 6)  ██╔══██╗██║██║     ██╔══██║██║"
    prin "$(color 6)  ██████╔╝██║███████╗██║  ██║███████╗"
    prin "$(color 6)  ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝"
    prin ""
    info "$(color 2) OS" distro
    info "$(color 2) Kernel" kernel
    info "$(color 2) Uptime" uptime
    info "$(color 2) Packages" packages
    info "$(color 2) Shell" shell
    info "$(color 2) DE" de
    info "$(color 2) WM" wm
    info "$(color 2) Terminal" term
    info "$(color 2) CPU" cpu
    info "$(color 2) Memory" memory
    info "$(color 2) Disk" disk
}
EOF

    # ── XFCE Desktop Profile ──
    chroot "$WORK_DIR/chroot" /bin/bash << XFCE_EOF
set -e
# Set XFCE wallpaper color theme (dark teal)
mkdir -p /home/${USERNAME}/.config/xfce4/xfconf/xfce-perchannel-xml

cat > /home/${USERNAME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'DESK'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="rgba1" type="array">
            <value type="double" value="0.047"/>
            <value type="double" value="0.251"/>
            <value type="double" value="0.337"/>
            <value type="double" value="1.000"/>
          </property>
          <property name="image-style" type="int" value="0"/>
        </property>
      </property>
    </property>
  </property>
</channel>
DESK

# Set panel theme
cat > /home/${USERNAME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'XS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita-dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 10"/>
    <property name="MonospaceFontName" type="string" value="DejaVu Sans Mono 10"/>
    <property name="CursorThemeSize" type="int" value="24"/>
  </property>
</channel>
XS

chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config
XFCE_EOF

    # ── Welcome Script ──
    cat > "$WORK_DIR/chroot/usr/local/bin/bilal-welcome" << 'EOF'
#!/bin/bash
echo ""
echo "  Welcome to Bilal OS — Horizon Edition"
echo "  ─────────────────────────────────────"
echo "  • Username : bilal"
echo "  • Password : bilal123"
echo "  • sudo     : no password required"
echo ""
neofetch
EOF
    chmod +x "$WORK_DIR/chroot/usr/local/bin/bilal-welcome"

    # Add welcome to .bashrc
    echo "[ -t 1 ] && bilal-welcome" \
        >> "$WORK_DIR/chroot/home/${USERNAME}/.bashrc"

    # ── Custom GRUB Theme ──
    mkdir -p "$WORK_DIR/chroot/boot/grub/themes/bilalos"
    cat > "$WORK_DIR/chroot/boot/grub/themes/bilalos/theme.txt" << 'EOF'
title-text: ""
desktop-color: "#0a0e1a"
terminal-font: "Noto Sans Regular 14"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"
terminal-border: "0"

+ boot_menu {
  left = 25%
  top = 35%
  width = 50%
  height = 50%
  item_font = "Noto Sans Regular 14"
  item_color = "#a0b4c8"
  selected_item_color = "#00d4ff"
  item_height = 32
  item_padding = 8
  item_spacing = 4
}

+ label {
  left = 0
  top = 20%
  width = 100%
  align = "center"
  text = "Bilal OS — Horizon Edition"
  font = "Noto Sans Bold 28"
  color = "#00d4ff"
}
EOF

    log "Bilal OS customizations applied"
}

# ─── CREATE SQUASHFS ─────────────────────────────────────────
create_squashfs() {
    step "Creating Compressed Filesystem (SquashFS)"
    progress "Compressing system (this takes 10-20 minutes)"

    # Cleanup before squash
    chroot "$WORK_DIR/chroot" /bin/bash << 'CLEAN'
apt-get clean
apt-get autoremove -y --purge
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* /var/tmp/*
rm -rf /var/log/*.log /var/log/**/*.log
find /var/cache -type f -delete
history -c
CLEAN

    mkdir -p "$WORK_DIR/binary/live"

    mksquashfs \
        "$WORK_DIR/chroot" \
        "$WORK_DIR/binary/live/filesystem.squashfs" \
        -comp xz \
        -Xbcj x86 \
        -b 1M \
        -e boot \
        -noappend \
        || error "mksquashfs failed"

    # Generate filesystem size
    printf "%s" "$(du -sx --block-size=1 "$WORK_DIR/chroot" | cut -f1)" \
        > "$WORK_DIR/binary/live/filesystem.size"

    log "SquashFS created: $(du -sh "$WORK_DIR/binary/live/filesystem.squashfs" | cut -f1)"
}

# ─── SETUP BOOTLOADER ────────────────────────────────────────
setup_bootloader() {
    step "Configuring Bootloader (GRUB + ISOLINUX)"

    # Copy kernel and initramfs
    cp "$WORK_DIR/chroot/boot/vmlinuz-"* \
       "$WORK_DIR/binary/live/vmlinuz"
    cp "$WORK_DIR/chroot/boot/initrd.img-"* \
       "$WORK_DIR/binary/live/initrd.img"

    # ── GRUB config (UEFI) ──
    mkdir -p "$WORK_DIR/binary/boot/grub"
    cat > "$WORK_DIR/binary/boot/grub/grub.cfg" << EOF
set default=0
set timeout=5
set gfxmode=1024x768
load_video

insmod gfxterm
insmod vbe
terminal_output gfxterm

set color_normal=cyan/black
set color_highlight=black/cyan

menuentry "Bilal OS ${OS_VERSION} — Live Session" --class bilalos {
    linux  /live/vmlinuz boot=live quiet splash hostname=${HOSTNAME} username=${USERNAME} components
    initrd /live/initrd.img
}

menuentry "Bilal OS — Safe Mode (nomodeset)" --class bilalos {
    linux  /live/vmlinuz boot=live nomodeset hostname=${HOSTNAME} username=${USERNAME} components
    initrd /live/initrd.img
}

menuentry "Bilal OS — Install to Disk" --class bilalos {
    linux  /live/vmlinuz boot=live hostname=${HOSTNAME} username=${USERNAME} components install
    initrd /live/initrd.img
}

menuentry "Boot from first hard disk" --class hdd {
    insmod chain
    set root=(hd0)
    chainloader +1
}

menuentry "Restart" { reboot }
menuentry "Power Off" { halt }
EOF

    # ── ISOLINUX config (BIOS) ──
    mkdir -p "$WORK_DIR/binary/isolinux"
    cp /usr/lib/ISOLINUX/isolinux.bin        "$WORK_DIR/binary/isolinux/"
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32  "$WORK_DIR/binary/isolinux/"
    cp /usr/lib/syslinux/modules/bios/libcom32.c32  "$WORK_DIR/binary/isolinux/"
    cp /usr/lib/syslinux/modules/bios/libutil.c32   "$WORK_DIR/binary/isolinux/"
    cp /usr/lib/syslinux/modules/bios/vesamenu.c32  "$WORK_DIR/binary/isolinux/"

    cat > "$WORK_DIR/binary/isolinux/isolinux.cfg" << EOF
UI vesamenu.c32
TIMEOUT 50
MENU TITLE Bilal OS ${OS_VERSION} — ${OS_CODENAME}
MENU COLOR TITLE    1;36;40 #ff00d4ff #00000000 std
MENU COLOR SEL      7;37;40 #ff000000 #ff00d4ff std
MENU COLOR BORDER   1;34;40 #ff006080 #00000000 std

LABEL live
    MENU LABEL Bilal OS — Live Session
    LINUX /live/vmlinuz
    INITRD /live/initrd.img
    APPEND boot=live quiet splash hostname=${HOSTNAME} username=${USERNAME} components

LABEL safe
    MENU LABEL Bilal OS — Safe Mode
    LINUX /live/vmlinuz
    INITRD /live/initrd.img
    APPEND boot=live nomodeset hostname=${HOSTNAME} username=${USERNAME} components

LABEL hd
    MENU LABEL Boot from Hard Disk
    COM32 chain.c32
    APPEND hd0
EOF

    log "Bootloader configured"
}

# ─── BUILD ISO ───────────────────────────────────────────────
build_iso() {
    step "Building ISO Image"
    progress "Generating final ISO (please wait)"

    local iso_path="$OUTPUT_DIR/$ISO_NAME"

    # Create EFI image
    local efi_img="$WORK_DIR/binary/boot/efi.img"
    dd if=/dev/zero of="$efi_img" bs=1M count=8 status=none
    mkfs.vfat "$efi_img"

    # Mount and populate EFI image
    local efi_mnt
    efi_mnt=$(mktemp -d)
    mount "$efi_img" "$efi_mnt"
    mkdir -p "$efi_mnt/EFI/BOOT"

    # Install GRUB EFI
    grub-mkimage \
        -d /usr/lib/grub/x86_64-efi \
        -o "$efi_mnt/EFI/BOOT/BOOTX64.EFI" \
        -O x86_64-efi \
        -p /boot/grub \
        fat iso9660 part_gpt part_msdos normal boot linux \
        configfile loopback chain efifwsetup efi_gop \
        squash4 memdisk png gfxterm gfxterm_background \
        gfxterm_menu test all_video loadenv exfat ext2

    cp "$WORK_DIR/binary/boot/grub/grub.cfg" \
       "$efi_mnt/EFI/BOOT/"
    umount "$efi_mnt"
    rmdir "$efi_mnt"

    # Build the ISO with xorriso
    xorriso \
        -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "BILALOS_${OS_VERSION//./_}" \
        -appid "Bilal OS ${OS_VERSION} (${OS_CODENAME})" \
        -publisher "Bilal OS Project" \
        -preparer "Built with bilal-os-build.sh" \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/efi.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -output "$iso_path" \
        "$WORK_DIR/binary" \
        || error "xorriso failed"

    log "ISO created: $iso_path"
    log "ISO size: $(du -sh "$iso_path" | cut -f1)"
}

# ─── UNMOUNT CHROOT ──────────────────────────────────────────
unmount_chroot() {
    for mnt in dev/pts dev proc sys; do
        if mountpoint -q "$WORK_DIR/chroot/$mnt" 2>/dev/null; then
            umount -lf "$WORK_DIR/chroot/$mnt" || true
        fi
    done
}

# ─── VERIFY ISO ──────────────────────────────────────────────
verify_iso() {
    step "Verifying ISO Integrity"

    local iso_path="$OUTPUT_DIR/$ISO_NAME"

    # Generate checksums
    progress "Generating SHA256 checksum"
    sha256sum "$iso_path" > "$OUTPUT_DIR/${ISO_NAME%.iso}.sha256"

    progress "Generating MD5 checksum"
    md5sum    "$iso_path" > "$OUTPUT_DIR/${ISO_NAME%.iso}.md5"

    log "Checksums saved to $OUTPUT_DIR"

    # Verify ISO structure
    if xorriso -indev "$iso_path" -report_system_area plain 2>/dev/null | \
        grep -q "MBR"; then
        log "ISO structure verified (MBR + GPT hybrid)"
    fi
}

# ─── FINAL SUMMARY ───────────────────────────────────────────
print_summary() {
    local iso_path="$OUTPUT_DIR/$ISO_NAME"
    local iso_size
    iso_size=$(du -sh "$iso_path" 2>/dev/null | cut -f1 || echo "N/A")

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}  ${BOLD}${WHITE}Build Complete! Bilal OS is ready.${RESET}                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}ISO File  :${RESET} $ISO_NAME"
    echo -e "${CYAN}║${RESET}  ${GREEN}Location  :${RESET} $iso_path"
    echo -e "${CYAN}║${RESET}  ${GREEN}Size      :${RESET} $iso_size"
    echo -e "${CYAN}║${RESET}  ${GREEN}Username  :${RESET} ${USERNAME}"
    echo -e "${CYAN}║${RESET}  ${GREEN}Password  :${RESET} ${PASSWORD}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}  ${YELLOW}To write to USB:${RESET}"
    echo -e "${CYAN}║${RESET}    sudo dd if=$ISO_NAME of=/dev/sdX bs=4M status=progress"
    echo -e "${CYAN}║${RESET}  ${YELLOW}To test in QEMU:${RESET}"
    echo -e "${CYAN}║${RESET}    qemu-system-x86_64 -m 2G -cdrom $ISO_NAME -boot d"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# ─── CLEANUP ON ERROR ────────────────────────────────────────
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\n${RED}[✗] Build failed (exit code: $exit_code)${RESET}"
        echo -e "${YELLOW}[!] Cleaning up mounts...${RESET}"
    fi
    unmount_chroot
}
trap cleanup EXIT

# ─── MAIN ────────────────────────────────────────────────────
main() {
    banner

    info "Building: ${BOLD}${OS_NAME} ${OS_VERSION} (${OS_CODENAME})${RESET}"
    info "Base    : Debian ${DEBIAN_SUITE} | Arch: ${ARCH}"
    info "Output  : $OUTPUT_DIR/$ISO_NAME"
    echo ""

    local start_time
    start_time=$(date +%s)

    check_requirements
    setup_directories
    bootstrap_system
    configure_chroot
    customize_bilal_os
    create_squashfs
    setup_bootloader
    build_iso
    unmount_chroot
    verify_iso

    local end_time elapsed
    end_time=$(date +%s)
    elapsed=$(( end_time - start_time ))

    print_summary
    log "Total build time: $((elapsed/60)) minutes $((elapsed%60)) seconds"
}

main "$@"
