#!/bin/bash
# Downgrade protection with min-bundle-version for chapters 11 and 12 of The Embedded AMD EDF Handbook.
# Needs: root, rauc 1.12 or later (tested with 1.15.2), openssl, squashfs-tools, dbus-daemon.
# Set RAUC to the rauc binary when it is not on PATH. Standalone: it builds its own test keys in ./work-dg.
# Writes the transcript to ./out/downgrade.txt (test keys only).
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work-dg; O=$HERE/out
RAUC=${RAUC:-rauc}
rm -rf "$W" /tmp/bl-state-dg /tmp/rauc-data-dg; mkdir -p "$W" "$O" /tmp/rauc-data-dg /run/dbus
clean() { LC_ALL=C sed "s/\x1b\[[0-9;]*m//g; s/[\x80-\xff]\+/ /g; s#$W/##g" | grep -v '^rauc-Message\|^$\|central status\|system status'; }
cd "$W"

openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ca.key.pem -out ca.cert.pem \
  -subj "/O=Handbook Test/CN=Handbook Test CA" -days 365 \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout dev.key.pem -out dev.csr \
  -subj "/O=Handbook Test/CN=Handbook Test Signer" 2>/dev/null
printf 'basicConstraints=CA:FALSE\nkeyUsage=digitalSignature\n' > plain.ext
openssl x509 -req -in dev.csr -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -out dev.cert.pem -days 365 -extfile plain.ext 2>/dev/null

mkdir -p payload/rootfs/etc && echo hello > payload/rootfs/etc/release
head -c 200000 /dev/urandom > payload/rootfs/payload.bin
mksquashfs payload/rootfs payload/rootfs.img -noappend -quiet >/dev/null
mkbundle() { # version out
  d=b-$2; mkdir -p "$d"; cp payload/rootfs.img "$d/"
  printf '[update]\ncompatible=handbook-vpk120\nversion=%s\n\n[bundle]\nformat=plain\n\n[image.rootfs]\nfilename=rootfs.img\n' "$1" > "$d/manifest.raucm"
  "$RAUC" bundle --cert dev.cert.pem --key dev.key.pem "$d" "$2.raucb" >/dev/null 2>&1; }
mkbundle 2026.11.1 v1
mkbundle 2026.11.2 v2
mkbundle 2026.11.3 v3
mkbundle 2026.1-r9 r9
mkbundle 2026.1-r10 r10

mkconf() { # name min-bundle-version
  cat > "$1" <<EOC
[system]
compatible=handbook-vpk120
bootloader=custom
data-directory=/tmp/rauc-data-dg
min-bundle-version=$2

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
}
mkconf sys-min2.conf 2026.11.2
mkconf sys-minr9.conf 2026.1-r9

cat > /etc/dbus-1/system.d/de.pengutronix.rauc.conf <<'EOP'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig><policy user="root"><allow own="de.pengutronix.rauc"/><allow send_destination="de.pengutronix.rauc"/></policy></busconfig>
EOP
pkill -x dbus-daemon 2>/dev/null; sleep 1; rm -f /run/dbus/pid; dbus-daemon --system --fork; sleep 1
truncate -s 2M /tmp/rootfs0 /tmp/rootfs1
export BL_STATE=/tmp/bl-state-dg
start() { pkill -x rauc 2>/dev/null; sleep 1; ("$RAUC" --conf "$1" service --override-boot-slot=A >/tmp/rauc-service-dg.log 2>&1 &); sleep 2; }
inst() { echo; echo "\$ rauc --conf $1 install $2"; "$RAUC" --conf "$1" install $2 2>&1 | clean | awk '!/Copying image/ || !s++{print}' | tail -${3:-3}; }

{ echo "\$ rauc --version"; "$RAUC" --version
  echo; echo '$ grep min-bundle-version sys-min2.conf'; grep min-bundle-version sys-min2.conf
  start sys-min2.conf
  inst sys-min2.conf v1.raucb
  inst sys-min2.conf v2.raucb
  inst sys-min2.conf v3.raucb
  inst sys-min2.conf "--ignore-version-limit v1.raucb"
  echo; echo '$ grep min-bundle-version sys-minr9.conf'; grep min-bundle-version sys-minr9.conf
  start sys-minr9.conf
  inst sys-minr9.conf r10.raucb
} > "$O/downgrade.txt"
pkill -x rauc; echo "done: $O/downgrade.txt"
