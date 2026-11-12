#!/bin/bash
# Build an initramfs from an init script, a list of kernel modules and a list of host binaries (with their shared libraries).
# Usage: mkinitramfs.sh OUT.cpio.gz INIT_SCRIPT "MODULE ..." "BINARY ..." [EXTRA_DIR]
# MODULES is a directory of decompressed .ko files named in $KMODS; BINARIES are copied with the libraries that ldd reports.
set -eu
OUT=$1; INIT=$2; MODS=$3; BINS=$4; EXTRA=${5:-}
R=$(mktemp -d); trap 'rm -rf "$R"' EXIT
mkdir -p "$R"/{bin,sbin,etc,proc,sys,dev,run,tmp,newroot,lib/modules,usr/bin,usr/sbin,var/run}
cp /usr/bin/busybox "$R/bin/busybox"
for a in sh ash mount umount mkdir mknod cat echo ls sleep insmod rmmod dd printf grep sed head tail cut tr sync poweroff reboot switch_root dmesg od hexdump basename dirname cp mv rm chmod ln ps kill pkill pidof seq stat wc sort uname find touch test true false tee date id ifconfig route ip chown ls; do ln -sf busybox "$R/bin/$a"; done
for m in $MODS; do cp "$KMODS/$m.ko" "$R/lib/modules/"; done
for b in $BINS; do
  p=$(command -v "$b" || echo "$b")
  mkdir -p "$R$(dirname "$p")"; cp -L "$p" "$R$p"
  ldd "$p" 2>/dev/null | awk '/=>/ {print $3} /^[ \t]*\/lib/ {print $1}' | grep '^/' | while read -r l; do
    mkdir -p "$R$(dirname "$l")"; [ -e "$R$l" ] || cp -L "$l" "$R$l"; done
done
[ -z "$EXTRA" ] || cp -a "$EXTRA"/. "$R"/
cp "$INIT" "$R/init"; chmod +x "$R/init"
(cd "$R" && find . | cpio -o -H newc --quiet | gzip -1) > "$OUT"
