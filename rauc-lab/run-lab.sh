#!/bin/bash
# Offline RAUC lab used for the examples in chapter 12 of The Embedded AMD EDF Handbook.
# Needs: root, rauc (tested with 1.11.3), openssl, squashfs-tools, dbus-daemon.
# Writes transcripts to ./out and leaves all keys and bundles in ./work (test keys only).
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work; O=$HERE/out
rm -rf "$W" "$O" /tmp/bl-state /tmp/rauc-data; mkdir -p "$W" "$O" /tmp/rauc-data /run/dbus
clean() { LC_ALL=C sed "s/\x1b\[[0-9;]*m//g; s/[\x80-\xff]\+/ /g; s/\([0-9]\)?kB/\1 kB/; s#$W/##g" | grep -v '^rauc-Message\|^$'; }
cd "$W"

# 1. Test PKI: one CA, a signer without extended key usage, a signer with codeSigning
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ca.key.pem -out ca.cert.pem \
  -subj "/O=Handbook Test/CN=Handbook Test CA" -days 365 \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout dev.key.pem -out dev.csr \
  -subj "/O=Handbook Test/CN=Handbook Test Signer" 2>/dev/null
printf 'basicConstraints=CA:FALSE\nkeyUsage=digitalSignature\n' > plain.ext
printf 'basicConstraints=CA:FALSE\nkeyUsage=digitalSignature\nextendedKeyUsage=codeSigning\n' > eku.ext
openssl x509 -req -in dev.csr -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -out dev.cert.pem -days 365 -extfile plain.ext 2>/dev/null
openssl x509 -req -in dev.csr -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -out dev-eku.cert.pem -days 365 -extfile eku.ext 2>/dev/null

# 2. Payload and bundles (a squashfs stands in for the ext4 root file system image)
mkdir -p payload/rootfs/etc && echo "version=2026.1-r2" > payload/rootfs/etc/handbook-release
head -c 600000 /dev/urandom > payload/rootfs/payload.bin
mksquashfs payload/rootfs payload/rootfs.img -noappend -quiet >/dev/null
mkbundle() { # format version cert out
  d=bundle-$1-$2; mkdir -p "$d"; cp payload/rootfs.img "$d/"
  printf '[update]\ncompatible=handbook-vpk120\nversion=%s\ndescription=Handbook example update\n\n[bundle]\nformat=%s\n\n[image.rootfs]\nfilename=rootfs.img\n' "$2" "$1" > "$d/manifest.raucm"
  rauc bundle --cert "$3" --key dev.key.pem "$d" "$4" >/dev/null 2>&1; }
mkbundle verity 2026.1-r2 dev.cert.pem update.raucb
mkbundle verity 2026.1-r2 dev-eku.cert.pem eku.raucb
mkbundle plain  2026.1-r3 dev.cert.pem plain.raucb

# 3. System configurations
cat > sys-custom.conf <<EOC
[system]
compatible=handbook-vpk120
bootloader=custom
data-directory=/tmp/rauc-data

[handlers]
bootloader-custom-backend=$HERE/backend.sh

[keyring]
path=$W/ca.cert.pem

[slot.rootfs.0]
device=/tmp/rootfs0
type=raw
bootname=A

[slot.rootfs.1]
device=/tmp/rootfs1
type=raw
bootname=B
EOC
sed 's#^path=.*#&\ncheck-purpose=codesign#' sys-custom.conf > sys-codesign.conf
sed "s#$W/ca.cert.pem#$W/other.cert.pem#" sys-custom.conf > sys-other.conf
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout other.key.pem -out other.cert.pem -subj "/O=Other/CN=Other CA" -days 30 2>/dev/null

# 4. Offline checks
{ echo '$ rauc --keyring ca.cert.pem info update.raucb'; rauc --keyring ca.cert.pem info update.raucb 2>&1 | clean | head -22
  echo; echo '$ rauc --conf sys-custom.conf info eku.raucb'; rauc --conf sys-custom.conf info eku.raucb 2>&1 | clean | grep -v 'central status\|system status' | head -3
  echo; echo '$ rauc --conf sys-codesign.conf info eku.raucb'; rauc --conf sys-codesign.conf info eku.raucb 2>&1 | clean | grep -v 'central status\|system status' | head -3
  echo; echo '$ rauc --conf sys-other.conf info update.raucb'; rauc --conf sys-other.conf info update.raucb 2>&1 | clean | grep -v 'central status\|system status\|Reading' | head -3
} > "$O/verify.txt"
cp update.raucb tamper-payload.raucb; printf '\x55' | dd of=tamper-payload.raucb bs=1 seek=300000 conv=notrunc 2>/dev/null
cp update.raucb tamper-sig.raucb; sz=$(stat -c %s update.raucb); printf '\x55' | dd of=tamper-sig.raucb bs=1 seek=$((sz-200)) conv=notrunc 2>/dev/null
{ echo '$ rauc --conf sys-custom.conf info tamper-sig.raucb'; rauc --conf sys-custom.conf info tamper-sig.raucb 2>&1 | clean | grep -v 'central status\|system status\|Reading'
  echo; echo '$ rauc --conf sys-custom.conf info tamper-payload.raucb'; rauc --conf sys-custom.conf info tamper-payload.raucb 2>&1 | clean | grep -v 'central status\|system status\|Reading' | head -3
  echo; echo '$ rauc --conf sys-custom.conf extract tamper-payload.raucb out-dir'; rauc --conf sys-custom.conf extract tamper-payload.raucb "$W/x" 2>&1 | clean | grep -v 'central status\|system status\|Reading' | tail -3
} > "$O/tamper.txt"


# 4b. Certificate validity depends on the device clock (needs faketime)
if command -v faketime >/dev/null; then
  { for d in "2020-01-01 00:00:00" "2026-10-31 00:00:00" "2028-01-01 00:00:00"; do
      echo "\$ faketime '$d' rauc --conf sys-custom.conf info update.raucb"
      faketime "$d" rauc --conf sys-custom.conf info update.raucb 2>&1 | clean | grep -v 'central status\|system status\|Reading\|Verifying' | head -2; echo; done
  } > "$O/clock.txt"
fi

# 5. Install into file-backed A/B slots with the test-double bootloader backend
pkill -x dbus-daemon 2>/dev/null; sleep 1; rm -f /run/dbus/pid; dbus-daemon --system --fork
cat > /etc/dbus-1/system.d/de.pengutronix.rauc.conf <<'EOP'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig><policy user="root"><allow own="de.pengutronix.rauc"/><allow send_destination="de.pengutronix.rauc"/></policy></busconfig>
EOP
pkill -x dbus-daemon; sleep 1; rm -f /run/dbus/pid; dbus-daemon --system --fork; sleep 1
truncate -s 2M /tmp/rootfs0 /tmp/rootfs1
start() { pkill -x rauc 2>/dev/null; sleep 1; (rauc --conf sys-custom.conf service ${1:+--override-boot-slot=$1} >/tmp/rauc-service.log 2>&1 &); sleep 2; }
start A
{ echo '$ rauc status'; rauc --conf sys-custom.conf status 2>&1 | clean
  echo; echo '$ rauc install plain.raucb'; rauc --conf sys-custom.conf install plain.raucb 2>&1 | clean | awk '!/Copying image/ || !s++{print}'
  echo; echo '$ cat /tmp/bl-state'; cat /tmp/bl-state
  echo; echo '$ rauc status'; rauc --conf sys-custom.conf status 2>&1 | clean
} > "$O/install.txt"
start B
{ echo '(simulated reboot into slot B: service started with --override-boot-slot=B)'
  echo '$ rauc status mark-good'; rauc --conf sys-custom.conf status mark-good 2>&1 | clean
  echo '$ cat /tmp/bl-state'; cat /tmp/bl-state
  echo; echo '$ rauc status mark-bad'; rauc --conf sys-custom.conf status mark-bad 2>&1 | clean
  echo '$ cat /tmp/bl-state'; cat /tmp/bl-state
} > "$O/markgood.txt"
{ echo '$ rauc --conf sys-custom.conf install update.raucb    (verity bundle)'; start A; rauc --conf sys-custom.conf install update.raucb 2>&1 | clean | tail -3; } > "$O/verity-install.txt"
pkill -x rauc; echo "done, transcripts in $O"
