#!/bin/bash
# Read only root with an overlay (chapter 7): squashfs lower layer, ext4 upper layer. Needs root, mksquashfs, loop and overlay support.
# Output goes to out/overlay.txt.
cd "$(dirname "$0")"; mkdir -p out; W=/tmp/ov; umount $W/merged $W/upperfs $W/lower 2>/dev/null; rm -rf $W; mkdir -p $W/{root/etc,lower,upperfs,merged}; cd $W
echo "hostname=factory" > root/etc/device.conf; echo "keep" > root/etc/other.conf
mksquashfs root lower.img -noappend -quiet >/dev/null
truncate -s 16M upper.img; mke2fs -q -F -t ext4 upper.img
mount -o loop,ro lower.img lower; mount -o loop upper.img upperfs; mkdir -p upperfs/upper upperfs/work
mount -t overlay overlay -o lowerdir=lower,upperdir=upperfs/upper,workdir=upperfs/work merged
O=$OLDPWD/out/overlay.txt
{
echo '$ echo "x" > lower/etc/new     # write to the squashfs layer directly'; (echo x > lower/etc/new) 2>&1 | sed 's#^[^:]*: line [0-9]*: ##'
echo '$ echo "hostname=unit42" > merged/etc/device.conf; rm merged/etc/other.conf; echo n > merged/etc/new'
echo "hostname=unit42" > merged/etc/device.conf; rm merged/etc/other.conf; echo n > merged/etc/new
echo '$ cat lower/etc/device.conf    # lower layer unchanged'; cat lower/etc/device.conf
echo '$ ls upperfs/upper/etc'; ls -l upperfs/upper/etc | awk 'NR>1{print $1, $5, $NF}'
echo '$ cat merged/etc/device.conf; ls merged/etc'; cat merged/etc/device.conf; ls merged/etc
echo '$ rm -rf upperfs/upper/etc/*    # factory reset: empty the upper layer, then mount the overlay again'
umount merged; rm -rf upperfs/upper/etc/*; mount -t overlay overlay -o lowerdir=lower,upperdir=upperfs/upper,workdir=upperfs/work merged
echo '$ cat merged/etc/device.conf; ls merged/etc'; cat merged/etc/device.conf; ls merged/etc
} > $O 2>&1
umount merged upperfs lower; cat $O
