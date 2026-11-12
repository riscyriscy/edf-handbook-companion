#!/bin/bash
# Failure cases for the troubleshooting chapter. Run run-lab.sh first: this script reuses its keys in ./work.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work; O=$HERE/out
clean() { LC_ALL=C sed "s/\x1b\[[0-9;]*m//g; s/[\x80-\xff]\+/ /g; s/\([0-9]\)?kB/\1 kB/; s#$W/##g" | grep -v '^rauc-Message\|^$\|central status\|system status'; }
cd "$W"
mk() { # name compatible extra-manifest-text
  d=bundle-$1; rm -rf "$d"; mkdir -p "$d"; cp payload/rootfs.img "$d/"
  printf '[update]\ncompatible=%s\nversion=2026.1-r4\n\n[bundle]\nformat=plain\n\n[image.rootfs]\nfilename=rootfs.img\n%s' "$2" "$3" > "$d/manifest.raucm"
  rauc bundle --cert dev.cert.pem --key dev.key.pem "$d" "$1.raucb" >/dev/null 2>&1; }
mk wrong-compat handbook-other ""
mk extra-slot handbook-vpk120 $'\n[image.bootloader]\nfilename=rootfs.img\n'
sed '/^\[keyring\]/,/^$/d' sys-custom.conf > sys-nokeyring.conf
pkill -x rauc 2>/dev/null; sleep 1; (rauc --conf sys-custom.conf service --override-boot-slot=A >/tmp/rauc-service.log 2>&1 &); sleep 2
{ echo '$ rauc --conf sys-custom.conf install wrong-compat.raucb'; rauc --conf sys-custom.conf install wrong-compat.raucb 2>&1 | clean | tail -3
  echo; echo '$ rauc --conf sys-custom.conf install extra-slot.raucb'; rauc --conf sys-custom.conf install extra-slot.raucb 2>&1 | clean | tail -3
  echo; echo '$ rauc --conf sys-nokeyring.conf info plain.raucb'; rauc --conf sys-nokeyring.conf info plain.raucb 2>&1 | clean | head -4
  echo; echo '$ rauc --conf sys-custom.conf install missing.raucb'; rauc --conf sys-custom.conf install missing.raucb 2>&1 | clean | tail -2
} > "$O/errors.txt"
pkill -x rauc; echo "done: $O/errors.txt"
