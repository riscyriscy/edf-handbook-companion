#!/bin/bash
# Signing time versus device clock (chapter 12). Run run-lab.sh first: this script reuses the keys and bundles in ./work.
# Needs rauc 1.11 or later and faketime. Writes out/signtime.txt.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work; O=$HERE/out
clean() { LC_ALL=C sed "s/\x1b\[[0-9;]*m//g; s/[\x80-\xff]\+/ /g; s#$W/##g" | grep -v '^rauc-Message\|^$\|central status\|system status\|Reading\|Verifying'; }
cd "$W"
sed 's#^path=.*#&\nuse-bundle-signing-time=true#' sys-custom.conf > sys-signtime.conf
verify() { # clock config bundle
  echo "\$ faketime '$1' rauc --conf $2 info $3"
  faketime "$1" rauc --conf "$2" info "$3" 2>&1 | clean | head -1; echo; }
mkdir -p b-late; cp payload/rootfs.img b-late/
printf '[update]\ncompatible=handbook-vpk120\nversion=2027.1-r1\n\n[bundle]\nformat=plain\n\n[image.rootfs]\nfilename=rootfs.img\n' > b-late/manifest.raucm
{
  echo "# A. Bundle signed on $(date -u -r update.raucb +%F), signer certificate valid until $(date -u -d "$(openssl x509 -in dev.cert.pem -noout -enddate | cut -d= -f2)" +%F)"
  for d in "2020-01-01 00:00:00" "2028-01-01 00:00:00"; do
    verify "$d" sys-custom.conf update.raucb
    verify "$d" sys-signtime.conf update.raucb
  done
  echo "# B. Bundle built on 2028-01-01, after the signer certificate expired"
  rm -f late.raucb; faketime '2028-01-01 00:00:00' rauc bundle --cert dev.cert.pem --key dev.key.pem b-late late.raucb 2>&1 | clean | tail -1
  [ -f late.raucb ] && verify '2028-01-02 00:00:00' sys-signtime.conf late.raucb
  echo "# C. Same expired key, bundle built with the build host clock set back to 2027-06-01"
  rm -f backdated.raucb; faketime '2027-06-01 00:00:00' rauc bundle --cert dev.cert.pem --key dev.key.pem b-late backdated.raucb 2>&1 | clean | tail -1
  verify '2028-01-02 00:00:00' sys-custom.conf backdated.raucb
  verify '2028-01-02 00:00:00' sys-signtime.conf backdated.raucb
} > "$O/signtime.txt"
cat "$O/signtime.txt"
