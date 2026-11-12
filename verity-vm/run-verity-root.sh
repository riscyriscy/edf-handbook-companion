#!/bin/bash
# A dm-verity root file system, end to end, in a QEMU guest (chapter 12). Run prepare-kernel.sh first.
# Needs qemu-system-x86_64, veritysetup, mksquashfs, busybox-static, cpio, python3. No root and no KVM. Writes out/verity-root.txt.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work/root; O=$HERE/out; export KMODS=$HERE/kernel/mods
rm -rf "$W"; mkdir -p "$W/tree/bin" "$W/tree/sbin" "$W/tree/data" "$W/tree/dev" "$W/tree/proc" "$W/tree/tmp" "$O"; cd "$W"
cp /usr/bin/busybox tree/bin/; for a in sh dd dmesg grep tail head mount poweroff cat uniq; do ln -s busybox tree/bin/$a; done
cp "$HERE/root-init" tree/sbin/init
python3 -I -c "import random; r=random.Random(5); open('tree/data/ok.bin','wb').write(r.randbytes(65536)); open('tree/data/marker.bin','wb').write(b'HANDBOOK-MARKER-BLOCK-'+r.randbytes(65000))"
mksquashfs tree root.squashfs -noappend -quiet -no-compression -no-fragments -all-time 0 -mkfs-time 0 -all-root >/dev/null   # stored uncompressed, so a byte of the file is a byte of the image
SZ=$(stat -c %s root.squashfs); PAD=$(( (4096 - SZ % 4096) % 4096 )); head -c $PAD /dev/zero >> root.squashfs
ROOTHASH=$(veritysetup format --salt=00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff --uuid=11111111-2222-3333-4444-555555555555 root.squashfs root.hash 2>&1 | tee format.txt | awk '/^Root hash:/ {print $3}')
"$HERE/mkinitramfs.sh" initramfs.gz "$HERE/init-verity-root" "libcrc32c dm-bufio dm-verity" "veritysetup"
OFF=$(python3 -I -c "d=open('root.squashfs','rb').read(); print(d.find(b'HANDBOOK-MARKER-BLOCK-'))")
cp root.squashfs data-bad.squashfs; printf '\x55' | dd of=data-bad.squashfs bs=1 seek=$((OFF+20000)) conv=notrunc 2>/dev/null
cp root.squashfs prog-bad.squashfs; printf '\x55' | dd of=prog-bad.squashfs bs=1 seek=$((OFF-500)) conv=notrunc 2>/dev/null   # bin/busybox ends just before data/marker.bin
cp root.hash hash-bad.hash; printf '\x55' | dd of=hash-bad.hash bs=1 seek=$((4096+10)) conv=notrunc 2>/dev/null
boot() { # label data hash roothash verityopt
  echo; echo "# $1"
  timeout 300 qemu-system-x86_64 -m 512 -nographic -no-reboot -accel tcg -kernel "$HERE/kernel/vmlinuz" -initrd initramfs.gz \
    -drive file=$2,if=virtio,format=raw,readonly=on -drive file=$3,if=virtio,format=raw,readonly=on \
    -append "console=ttyS0 panic=-1 loglevel=4 handbook.roothash=$4 handbook.verityopt=$5" 2>&1 | tr -d '\r' \
    | grep -E "^(initramfs|root|Verity|type|status|hash|data|\[.*device-mapper: verity)|device-mapper: verity|I/O error|Buffer I/O|restart|Restarting|reboot|Kernel panic" | sed 's/^\[ *[0-9.]*\] //' | grep -v "sha256 using implementation\|Power down\|^ " | awk "!seen[\$0]++" | head -${LINES_MAX:-24}
}
{
  echo "# root hash from veritysetup format: $ROOTHASH"
  echo "# image: $(stat -c %s root.squashfs) bytes, hash tree: $(stat -c %s root.hash) bytes; marker file at image offset $OFF"
  boot "1. Clean image, correct root hash" root.squashfs root.hash $ROOTHASH ""
  boot "2. One byte changed in data/marker.bin inside the image" data-bad.squashfs root.hash $ROOTHASH ""
  boot "3. The same damage, device opened with --restart-on-corruption" data-bad.squashfs root.hash $ROOTHASH "--restart-on-corruption"
  boot "4. One byte changed in the last block of bin/busybox, the program that runs as process 1" prog-bad.squashfs root.hash $ROOTHASH ""
  boot "5. Root hash on the command line is wrong by one digit" root.squashfs root.hash "${ROOTHASH:0:63}$([ "${ROOTHASH:63:1}" = 0 ] && echo 1 || echo 0)" ""
  boot "6. One byte changed in the hash tree" root.squashfs hash-bad.hash $ROOTHASH ""
} | tee "$O/verity-root.txt"
