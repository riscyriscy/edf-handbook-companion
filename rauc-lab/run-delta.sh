#!/bin/bash
# How much of a new root file system image can a block-level delta (RAUC adaptive=block-hash-index) reuse from the old one? (chapter 12)
# Builds two releases of a synthetic root tree in ext4 and in squashfs and counts the 4 KiB blocks of the new image that already exist
# in the old image. Needs e2fsprogs (mke2fs -d), squashfs-tools, python3, rauc. Output goes to out/delta.txt.
cd "$(dirname "$0")"; HERE=$PWD; mkdir -p out; W=/tmp/delta; rm -rf $W; mkdir -p $W/r1; cd $W
python3 - <<'PY'
import os, random
random.seed(7)
words = [bytes(random.choices(b"abcdefghijklmnopqrstuvwxyz", k=random.randint(3, 9))) for _ in range(400)]
os.makedirs("r1/usr/lib"); os.makedirs("r1/usr/bin"); os.makedirs("r1/etc")
for i in range(150):   # 150 files of 40 to 120 KiB of text-like data, which compresses
    n = random.randint(40, 120) * 1024
    out = bytearray()
    while len(out) < n: out += random.choice(words) + b" "
    open(f"r1/usr/lib/lib{i:03d}.so", "wb").write(out[:n])
for i in range(60):    # 60 files of 100 to 300 KiB of random data, which does not
    open(f"r1/usr/bin/tool{i:03d}", "wb").write(random.randbytes(random.randint(100, 300) * 1024))
open("r1/etc/release", "w").write("2026.1\n")
PY
cp -a r1 r2
head -c 110000 /dev/urandom > r2/usr/bin/tool030       # one application replaced
head -c 200000 /dev/urandom > r2/usr/bin/zz-newtool       # one added
echo "2026.2" > r2/etc/release
mkext4() { E2FSPROGS_FAKE_TIME=1700000000 mke2fs -q -F -t ext4 -b 4096 -U 11111111-2222-3333-4444-555555555555 -E hash_seed=11111111-2222-3333-4444-555555555555,lazy_itable_init=0,root_owner=0:0 -O ^has_journal -d $1 $2 96M; }
mkext4 r1 r1.ext4; mkext4 r2 r2.ext4
for b in 4096 131072; do
  mksquashfs r1 r1.sq$b -noappend -quiet -b $b -all-root -mkfs-time 0 -all-time 0 >/dev/null; mksquashfs r2 r2.sq$b -noappend -quiet -b $b -all-root -mkfs-time 0 -all-time 0 >/dev/null
done
python3 - <<'PY' > $HERE/out/delta.txt
import hashlib, os
def blocks(p):
    d = open(p, "rb").read(); d += b"\0" * (-len(d) % 4096)
    return [d[i:i+4096] for i in range(0, len(d), 4096)]
print("%-26s %10s %12s %12s %14s %10s" % ("image format", "size MiB", "data blocks", "same place", "found anywhere", "to fetch"))
for name, a, b in (("ext4, 4 KiB blocks", "r1.ext4", "r2.ext4"), ("squashfs, 4 KiB blocks", "r1.sq4096", "r2.sq4096"), ("squashfs, 128 KiB blocks", "r1.sq131072", "r2.sq131072")):
    A, B = blocks(a), blocks(b)
    old = {hashlib.sha256(x).digest() for x in A}
    zero = hashlib.sha256(b"\0" * 4096).digest()
    nz = [i for i, x in enumerate(B) if hashlib.sha256(x).digest() != zero]    # empty blocks need no transfer
    same = sum(1 for i in nz if i < len(A) and A[i] == B[i])
    anywhere = sum(1 for i in nz if hashlib.sha256(B[i]).digest() in old)
    fetch = (len(nz) - anywhere) * 4096
    print("%-26s %10.1f %12d %11.1f%% %13.1f%% %7.1f MiB" % (name, os.path.getsize(b) / 2**20, len(nz), 100 * same / len(nz), 100 * anywhere / len(nz), fetch / 2**20))
PY
cat $HERE/out/delta.txt

# A verity bundle that carries the hash index. Needs the keys from run-lab.sh in ./work.
K=$HERE/work
if [ -f "$K/dev.key.pem" ]; then
  cd $W; mkdir -p bundle-ad bundle-bad
  mkm() { printf '[update]\ncompatible=handbook-vpk120\nversion=2026.2-r1\n\n[bundle]\nformat=verity\n\n[image.rootfs]\nfilename=%s\nadaptive=block-hash-index\n' $2 > $1/manifest.raucm; }
  cp r2.ext4 bundle-ad/rootfs.img; mkm bundle-ad rootfs.img
  head -c 1000001 /dev/urandom > bundle-bad/rootfs.img; mkm bundle-bad rootfs.img
  {
  echo; echo '$ rauc bundle --cert dev.cert.pem --key dev.key.pem bundle-ad adaptive.raucb   # manifest: format=verity, adaptive=block-hash-index'
  rauc bundle --cert $K/dev.cert.pem --key $K/dev.key.pem bundle-ad adaptive.raucb 2>&1 | grep -v "^rauc-Message" | tail -2
  echo '$ rauc info adaptive.raucb | grep -i "format\|adaptive\|size"'
  rauc --conf $K/sys-custom.conf info adaptive.raucb 2>&1 | LC_ALL=C sed 's/\x1b\[[0-9;]*m//g; s/[\x80-\xff]\+/ /g' | sed 's/\([0-9]\)?MB/\1 MB/' | grep -v "^rauc-Message" | grep -i "bundle format\|adaptive\|Size:"
  rb() { rauc bundle --cert $K/dev.cert.pem --key $K/dev.key.pem "$@" 2>&1 | LC_ALL=C sed 's/\x1b\[[0-9;]*m//g' | grep -v "^rauc-Message\|^$\|^Creating"; echo "exit status ${PIPESTATUS[0]}"; }
  echo; echo '$ rauc bundle ... bundle-bad x.raucb   # adaptive=block-hash-index, image of 1000001 bytes (not a multiple of 4096)'
  rb bundle-bad x.raucb
  head -c 1003520 /dev/urandom > bundle-bad/rootfs.img
  echo '$ rauc bundle ... bundle-bad x.raucb   # same manifest, image of 1003520 bytes (245 x 4096)'
  rb bundle-bad x.raucb
  head -c 1000001 /dev/urandom > bundle-bad/rootfs.img; sed -i '/^adaptive=/d' bundle-bad/manifest.raucm
  echo '$ rauc bundle ... bundle-bad x2.raucb   # image of 1000001 bytes, adaptive line removed'
  rb bundle-bad x2.raucb
  } >> $HERE/out/delta.txt 2>&1
fi
cat $HERE/out/delta.txt | tail -14
