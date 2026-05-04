#!/bin/bash
# ============================================================
#  Phase 0: Host System Requirements Check
#  Verifies all required tools and versions before building
# ============================================================

source "$(dirname "$0")/../../build.sh" 2>/dev/null || true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

check_tool() {
  local tool=$1 min_ver=$2
  if command -v "$tool" &>/dev/null; then
    local ver
    ver=$("$tool" --version 2>&1 | head -1 | grep -oP '\d+\.\d+[\.\d]*' | head -1)
    echo -e "${GREEN}  ✔${NC} $tool $ver"
    ((PASS++))
  else
    echo -e "${RED}  ✘${NC} $tool — NOT FOUND (required >= $min_ver)"
    ((FAIL++))
  fi
}

check_symlink() {
  local link=$1 target=$2
  if [ -L "$link" ] && [[ "$(readlink "$link")" == *"$target"* ]]; then
    echo -e "${GREEN}  ✔${NC} $link → $target"
    ((PASS++))
  else
    echo -e "${YELLOW}  ⚠${NC} $link should point to $target"
    ((WARN++))
  fi
}

check_kernel_param() {
  local param=$1
  if grep -q "$param" /proc/filesystems 2>/dev/null || \
     zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_${param}=y"; then
    echo -e "${GREEN}  ✔${NC} Kernel: $param enabled"
    ((PASS++))
  else
    echo -e "${YELLOW}  ⚠${NC} Kernel: $param (check manually)"
    ((WARN++))
  fi
}

echo ""
echo "══════════════════════════════════════"
echo "  Checking Host System Requirements"
echo "══════════════════════════════════════"

echo ""
echo "── Core Build Tools ─────────────────"
check_tool bash    "3.2"
check_tool gcc     "6.2"
check_tool g++     "6.2"
check_tool make    "4.0"
check_tool ld      "2.25"
check_tool bison   "2.7"
check_tool yacc    "any"
check_tool gawk    "4.0.1"
check_tool m4      "1.4.10"
check_tool grep    "2.5.1"
check_tool sed     "4.1.5"
check_tool tar     "1.22"
check_tool xz      "5.0.0"
check_tool patch   "2.5.4"
check_tool python3 "3.4"
check_tool perl    "5.8.8"
check_tool texinfo "5.0"

echo ""
echo "── Download Tools ───────────────────"
check_tool wget  "any"
check_tool curl  "any"

echo ""
echo "── Compression Tools ────────────────"
check_tool gzip  "any"
check_tool bzip2 "any"
check_tool unzip "any"

echo ""
echo "── Symlinks ─────────────────────────"
check_symlink /bin/sh    "bash"
check_symlink /usr/bin/awk  "gawk"
check_symlink /usr/bin/yacc "bison"

echo ""
echo "── Kernel Features ──────────────────"
check_kernel_param "ext4"
check_kernel_param "proc"
check_kernel_param "sysfs"

echo ""
echo "── Disk Space ───────────────────────"
FREE_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
if [ "$FREE_GB" -ge 30 ]; then
  echo -e "${GREEN}  ✔${NC} Free space: ${FREE_GB}GB (need ≥ 30GB)"
  ((PASS++))
else
  echo -e "${RED}  ✘${NC} Free space: ${FREE_GB}GB — need at least 30GB!"
  ((FAIL++))
fi

echo ""
echo "── Memory ───────────────────────────"
MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$MEM_GB" -ge 2 ]; then
  echo -e "${GREEN}  ✔${NC} RAM: ${MEM_GB}GB (need ≥ 2GB)"
  ((PASS++))
else
  echo -e "${YELLOW}  ⚠${NC} RAM: ${MEM_GB}GB — build may be slow"
  ((WARN++))
fi

echo ""
echo "══════════════════════════════════════"
echo -e "  Results: ${GREEN}$PASS passed${NC} | ${YELLOW}$WARN warnings${NC} | ${RED}$FAIL failed${NC}"
echo "══════════════════════════════════════"

[ "$FAIL" -gt 0 ] && {
  echo -e "${RED}  ✘ Fix failures before building!${NC}"
  exit 1
}
[ "$WARN" -gt 0 ] && echo -e "${YELLOW}  ⚠ Warnings found — review before continuing${NC}"
echo -e "${GREEN}  ✔ Host system is ready for LFS build!${NC}"
