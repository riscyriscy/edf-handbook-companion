#!/bin/bash
# RAUC verity bundles installed in a QEMU guest that has device-mapper (chapter 12). Run prepare-kernel.sh first.
# Needs qemu-system-x86_64, rauc 1.11, openssl, cpio, busybox-static, util-linux, dbus-daemon, python3. No root and no KVM.
# Writes out/rauc-verity.txt. Payloads are random files (4 KiB blocks), so the saving of an adaptive update is the saving of the blocks that did not change.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work/rauc; O=$HERE/out; export KMODS=$HERE/kernel/mods
rm -rf "$W"; mkdir -p "$W/lab" "$O"; cd "$W/lab"
# 1. Test PKI, payloads and bundles
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ca.key.pem -out ca.cert.pem -subj "/O=Handbook Test/CN=Handbook Test CA" -days 3650 \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout dev.key.pem -out dev.csr -subj "/O=Handbook Test/CN=Handbook Test Signer" 2>/dev/null
printf 'basicConstraints=CA:FALSE\nkeyUsage=digitalSignature\n' > plain.ext
openssl x509 -req -in dev.csr -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -out dev.cert.pem -days 3650 -extfile plain.ext 2>/dev/null
python3 -I - <<'PY'
import random
random.seed(11); blocks = [random.randbytes(4096) for _ in range(1280)]            # img1: 1280 blocks = 5 MiB
open("img1","wb").write(b"".join(blocks))
b2 = list(blocks)
for i in range(10, 18): b2[i] = random.randbytes(4096)                                 # img2: 8 blocks changed (32 KiB)
open("img2","wb").write(b"".join(b2))
b3 = list(b2)
for i in range(200, 204): b3[i] = random.randbytes(4096)                              # img3: 4 more blocks changed
open("img3","wb").write(b"".join(b3))
open("img4","wb").write(random.randbytes(4096*1280))                                  # img4: unrelated to the others
PY
mkb() { # name image version extra-bundle-line
  d=b-$1; mkdir -p $d; cp $2 $d/rootfs.img
  printf '[update]\ncompatible=handbook-vpk120\nversion=%s\n\n[bundle]\nformat=verity\n\n[image.rootfs]\nfilename=rootfs.img\n%s\n' "$3" "$4" > $d/manifest.raucm
  rauc --cert dev.cert.pem --key dev.key.pem bundle $d $1.raucb >/dev/null 2>&1; }
mkb v1n img1 2026.1-r1 ""
mkb v2n img2 2026.1-r2 ""
mkb v4n img4 2026.1-r4 ""
mkb v1 img1 2026.1-r1 "adaptive=block-hash-index"
mkb v2 img2 2026.1-r2 "adaptive=block-hash-index"
mkb v3 img3 2026.1-r3 "adaptive=block-hash-index"
rm -rf b-v1n b-v4n b-v2n b-v1 b-v2 b-v3 dev.csr
cp v4n.raucb tamper-payload.raucb; printf '\x55' | dd of=tamper-payload.raucb bs=1 seek=300000 conv=notrunc 2>/dev/null
cp v2n.raucb tamper-sig.raucb; sz=$(stat -c %s v2n.raucb); printf '\x55' | dd of=tamper-sig.raucb bs=1 seek=$((sz-200)) conv=notrunc 2>/dev/null
cp "$HERE/backend.sh" backend.sh 2>/dev/null || cp "$HERE/../rauc-lab/backend.sh" backend.sh
cat > sys.conf <<'EOC'
[system]
compatible=handbook-vpk120
bootloader=custom
data-directory=/tmp/rauc-data

[handlers]
bootloader-custom-backend=/lab/backend.sh

[keyring]
path=/lab/ca.cert.pem

[slot.rootfs.0]
device=/dev/vda
type=raw
bootname=A

[slot.rootfs.1]
device=/dev/vdb
type=raw
bootname=B
EOC
# Mutual TLS: an update server CA and server certificate, and units provisioned by the factory scripts of Chapter 14
mkdir -p tls "$W/prov"; mkca() { openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout $1.key.pem -out $1.cert.pem -subj "/O=Handbook Test/CN=$2" -days 3650 \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null; }
mkdir -p "$W/prov/ca" "$W/prov/ca2"; mkca "$W/prov/ca/ca" "Handbook Factory CA"; mkca "$W/prov/ca2/ca" "Other Factory CA"; mkca "$W/prov/server-ca" "Handbook Update Server CA"
mv "$W/prov/ca/ca.key.pem" "$W/prov/ca/ca.cert.pem" "$W/prov/ca/" 2>/dev/null
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout tls/server.key.pem -out "$W/prov/server.csr" -subj "/O=Handbook Test/CN=updates.example" 2>/dev/null
printf 'basicConstraints=CA:FALSE\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=IP:10.0.2.2\n' > "$W/prov/server.ext"
openssl x509 -req -in "$W/prov/server.csr" -CA "$W/prov/server-ca.cert.pem" -CAkey "$W/prov/server-ca.key.pem" -CAcreateserial -out tls/server.cert.pem -days 3650 -extfile "$W/prov/server.ext" 2>/dev/null
cp "$W/prov/server-ca.cert.pem" tls/server-ca.cert.pem; cp "$W/prov/ca/ca.cert.pem" tls/factory-ca.cert.pem
"$HERE/../provision/provision-unit.sh" "$W/prov/units/HB000001" HB000001 "$W/prov/ca" "$W/prov/ledger.csv" >/dev/null
"$HERE/../provision/provision-unit.sh" "$W/prov/units/HB000002" HB000002 "$W/prov/ca2" "$W/prov/ledger2.csv" >/dev/null
cp "$W/prov/units/HB000001/identity/device.cert.pem" tls/device.cert.pem; cp "$W/prov/units/HB000001/identity/device.key.pem" tls/device.key.pem
cp "$W/prov/units/HB000002/identity/device.cert.pem" tls/wrong.cert.pem; cp "$W/prov/units/HB000002/identity/device.key.pem" tls/wrong.key.pem
for v in tls:"tls-cert=/lab/tls/device.cert.pem\ntls-key=/lab/tls/device.key.pem\n" wrong:"tls-cert=/lab/tls/wrong.cert.pem\ntls-key=/lab/tls/wrong.key.pem\n" nocert:""; do
  cp sys.conf sys-${v%%:*}.conf; printf '\n[streaming]\nsandbox-user=nobody\ntls-ca=/lab/tls/server-ca.cert.pem\n'"${v#*:}" >> sys-${v%%:*}.conf; done
printf '\n[streaming]\nsandbox-user=nobody\n' >> sys.conf
cat > bus.conf <<'EOC'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig><type>system</type><listen>unix:path=/run/dbus/system_bus_socket</listen>
<policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy></busconfig>
EOC
cp "$HERE/tests-rauc.sh" tests.sh
# 2. Initramfs with RAUC and its libraries, then the guest run
mkdir -p "$W/extra/etc" "$W/extra/usr/share"; printf "root:x:0:0:root:/:/bin/sh\nnobody:x:65534:65534:nobody:/:/bin/false\n" > "$W/extra/etc/passwd"; printf "root:x:0:\nnogroup:x:65534:\n" > "$W/extra/etc/group"
mkdir -p "$W/extra/lab"; cp -a "$W/lab/." "$W/extra/lab/"
"$HERE/mkinitramfs.sh" "$W/initramfs.gz" "$HERE/init-rauc-lab" "libcrc32c dm-bufio dm-verity nbd" "rauc dbus-daemon mount umount losetup cmp" "$W/extra"
python3 -I "$HERE/range-server.py" "$W/lab" 8099 "$W/http.log" & SRV=$!
python3 -I "$HERE/range-server.py" "$W/lab" 8443 "$W/https.log" "$W/lab/tls/server.cert.pem" "$W/lab/tls/server.key.pem" "$W/lab/tls/factory-ca.cert.pem" & SRV2=$!
truncate -s 5M "$W/slotA.img" "$W/slotB.img"
timeout 900 qemu-system-x86_64 -m 1024 -nographic -no-reboot -accel tcg -kernel "$HERE/kernel/vmlinuz" -initrd "$W/initramfs.gz" \
  -drive file="$W/slotA.img",if=virtio,format=raw -drive file="$W/slotB.img",if=virtio,format=raw -nic user,model=virtio-net-pci -append "console=ttyS0 panic=-1 loglevel=3 quiet" 2>&1 | tr -d '\r' > "$W/serial.txt"
kill $SRV $SRV2 2>/dev/null
{ tr -d '\033' < "$W/serial.txt" | sed 's/c\[?7l\[2J//' | sed -n '/guest: kernel/,$p' | grep -a -v "^rauc-Message\|^$\|reboot: Power down\|^--stream-"
  echo; echo "# Bytes the web server sent, from its request log (sizes of the bundles: v2n.raucb $(stat -c %s "$W/lab/v2n.raucb"), v3.raucb $(stat -c %s "$W/lab/v3.raucb"))"
  awk '{n[$2]+=$4; c[$2]++} END {for (k in n) printf "%s: %d requests, %d bytes\n", k, c[k], n[k]}' "$W/http.log" | sort
  echo; echo "# What the TLS server logged (requests by client certificate common name, and refused handshakes)"
  awk '$1=="REFUSED" {r[$3 " " $4 " " $5 " " $6]++; next} {c[$6]++} END {for (k in c) printf "client %s: %d requests\n", k, c[k]; for (k in r) printf "refused: %s (%d)\n", k, r[k]}' "$W/https.log" 2>/dev/null | sort
} | tee "$O/rauc-verity.txt"
