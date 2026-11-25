#!/bin/bash
# Newer RAUC settings for chapters 12 and 17 of The Embedded AMD EDF Handbook: prevent-late-fallback (1.14),
# allowed-signer-cns (1.15) and an artifact repository of type files (1.13, preview).
# Needs: root, rauc 1.15 or later (tested with 1.15.2), openssl, squashfs-tools, dbus-daemon.
# Set RAUC to the rauc binary when it is not on PATH. Standalone: it builds its own test keys in ./work-new.
# Writes the transcript to ./out/newer.txt (test keys only).
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work-new; O=$HERE/out
RAUC=${RAUC:-rauc}
rm -rf "$W" /tmp/bl-state-nw /tmp/rauc-data-nw /tmp/add-ons; mkdir -p "$W" "$O" /tmp/rauc-data-nw /tmp/add-ons /run/dbus
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
mkdir -p b-os b-art; cp payload/rootfs.img b-os/
printf '[update]\ncompatible=handbook-vpk120\nversion=2026.11.5\n\n[bundle]\nformat=plain\n\n[image.rootfs]\nfilename=rootfs.img\n' > b-os/manifest.raucm
"$RAUC" bundle --cert dev.cert.pem --key dev.key.pem b-os os.raucb >/dev/null 2>&1
head -c 4096 /dev/urandom > b-art/app-1.bin
mkart() { printf '[update]\ncompatible=handbook-vpk120\nversion=2026.11.5\n\n[bundle]\nformat=%s\n\n[image.add-ons/app-1]\nfilename=app-1.bin\n' "$1" > b-art/manifest.raucm
  "$RAUC" bundle --cert dev.cert.pem --key dev.key.pem b-art "$2" 2>&1 | clean | tail -1; }

mkconf() { # name extra-system-lines extra-keyring-lines extra-sections
  cat > "$1" <<EOC
[system]
compatible=handbook-vpk120
bootloader=custom
data-directory=/tmp/rauc-data-nw
$2

[handlers]
bootloader-custom-backend=$HERE/backend.sh

[keyring]
path=$W/ca.cert.pem
$3

[slot.rootfs.0]
device=/tmp/rootfs0
type=raw
bootname=A

[slot.rootfs.1]
device=/tmp/rootfs1
type=raw
bootname=B
$4
EOC
}
mkconf sys-plain.conf "" "" ""
mkconf sys-plf.conf "prevent-late-fallback=true" "" ""
mkconf sys-cn-bad.conf "" "allowed-signer-cns=Other Name;Another Name" ""
mkconf sys-cn-ok.conf "" "allowed-signer-cns=Other Name;Handbook Test Signer" ""
mkconf sys-art.conf "" "" "
[artifacts.add-ons]
path=/tmp/add-ons
type=files"

cat > /etc/dbus-1/system.d/de.pengutronix.rauc.conf <<'EOP'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig><policy user="root"><allow own="de.pengutronix.rauc"/><allow send_destination="de.pengutronix.rauc"/></policy></busconfig>
EOP
pkill -x dbus-daemon 2>/dev/null; sleep 1; rm -f /run/dbus/pid; dbus-daemon --system --fork; sleep 1
truncate -s 2M /tmp/rootfs0 /tmp/rootfs1
export BL_STATE=/tmp/bl-state-nw
start() { pkill -x rauc 2>/dev/null; sleep 1; ("$RAUC" --conf "$1" service --override-boot-slot="$2" >/tmp/rauc-service-nw.log 2>&1 &); sleep 2; }
inst() { echo; echo "\$ rauc --conf $1 install $2"; "$RAUC" --conf "$1" install "$2" 2>&1 | clean | grep -v '^idle$' | awk '!/Copying image/ || !s++{print}' | tail -${3:-3}; }

late() { # conf
  rm -f $BL_STATE; start "$1" A
  echo; echo "# --conf $1: install to slot B, reboot into B, mark good"
  "$RAUC" --conf "$1" install os.raucb >/dev/null 2>&1
  start "$1" B
  echo "\$ rauc --conf $1 status mark-good"; "$RAUC" --conf "$1" status mark-good 2>&1 | clean
  echo '$ cat /tmp/bl-state-nw'; cat $BL_STATE
}
{ echo "\$ rauc --version"; "$RAUC" --version
  echo; echo '$ grep prevent-late-fallback sys-plf.conf'; grep prevent-late-fallback sys-plf.conf
  late sys-plain.conf
  late sys-plf.conf
  echo; echo '$ grep allowed-signer-cns sys-cn-bad.conf'; grep allowed-signer-cns sys-cn-bad.conf
  rm -f $BL_STATE; start sys-cn-bad.conf A
  inst sys-cn-bad.conf os.raucb 4
  echo; echo '$ grep allowed-signer-cns sys-cn-ok.conf'; grep allowed-signer-cns sys-cn-ok.conf
  rm -f $BL_STATE; start sys-cn-ok.conf A
  inst sys-cn-ok.conf os.raucb 2
  echo; echo '$ grep -A2 artifacts sys-art.conf'; grep -A2 artifacts sys-art.conf
  echo; echo '$ rauc bundle ... b-art art-plain.raucb    (manifest: format=plain, [image.add-ons/app-1])'
  mkart plain art-plain.raucb
  echo; echo '$ rauc bundle ... b-art art.raucb          (manifest: format=verity)'
  mkart verity art.raucb
  echo; echo '$ rauc --conf sys-art.conf info art.raucb'
  "$RAUC" --conf sys-art.conf info art.raucb 2>&1 | clean | grep -v 'Reading\|Verifying\|Verified\|Hash\|Salt\|Size:  \|Not \|SPKI\|Subject\|Issuer\|Serial' | head -16
  rm -f $BL_STATE; start sys-art.conf A
  inst sys-art.conf art.raucb 3
} > "$O/newer.txt" 2>&1
pkill -x rauc; echo "done: $O/newer.txt"
