#!/bin/bash
# What e2fsck -p (the mode used at boot) does with three kinds of damage, and its exit status. Needs e2fsprogs. Output: out/fsck.txt.
cd "$(dirname "$0")"; mkdir -p out; W=/tmp/fsck; rm -rf $W; mkdir -p $W; cd $W
mk() { rm -f t.img; truncate -s 32M t.img; mke2fs -q -F -t ext4 -L data t.img
       mkdir -p m; mount -o loop t.img m; for i in 1 2 3 4 5; do head -c 200000 /dev/urandom > m/f$i; done; sync; umount m; }
runp() { echo "\$ e2fsck -p -f t.img   # $1"; e2fsck -p -f t.img 2>&1 | sed 's/t.img: //; s/ ([0-9]*\/[0-9]* files, [0-9]*\/[0-9]* blocks)//' | head -${2:-4}; echo "exit status ${PIPESTATUS[0]}"; echo; }
{
mk; runp "undamaged"
mk; debugfs -w -R "sif /f2 links_count 7" t.img >/dev/null 2>&1; runp "link count of one file wrong"
mk; debugfs -w -R "freeb 100 50" t.img >/dev/null 2>&1; runp "bitmap says 50 blocks are free that hold data"
mk; debugfs -w -R "sif /f3 block[0] 12" t.img >/dev/null 2>&1; runp "a file points into the metadata area" 6
mk; dd if=/dev/zero of=t.img bs=1k seek=1 count=1 conv=notrunc 2>/dev/null; runp "primary superblock zeroed" 5
} > $OLDPWD/out/fsck.txt 2>&1
cat $OLDPWD/out/fsck.txt
