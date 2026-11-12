#!/bin/bash
# Download the Ubuntu 24.04 6.8 generic kernel and extract the kernel image and the three modules the labs need into ./kernel.
# The image has dm-mod, ext4, squashfs, loop and virtio built in, and dm-verity, dm-bufio and nbd as modules.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd); K=$HERE/kernel; mkdir -p "$K/debs" "$K/mods"; cd "$K/debs"
V=$(apt-cache search --names-only '^linux-image-unsigned-6\.8\.0-[0-9]+-generic$' | sort -V | tail -1 | cut -d' ' -f1 | sed 's/linux-image-unsigned-//')
apt-get download linux-image-unsigned-$V linux-modules-$V >/dev/null
mkdir -p "$K/x"; for d in *.deb; do dpkg-deb -x "$d" "$K/x"; done
cp "$K/x/boot/vmlinuz-$V" "$K/vmlinuz"; cp "$K/x/boot/config-$V" "$K/config"
for m in dm-verity dm-bufio libcrc32c nbd; do zstd -dqf "$(find "$K/x/lib/modules/$V" -name "$m.ko.zst")" -o "$K/mods/$m.ko"; done
echo "$V" > "$K/version"; echo "kernel $V in $K"
