#!/bin/bash
# Run the budget gate (chapter 15) on a scripted boot, on fixtures and on real ext4 images. Output goes to out/budgets.txt.
# Needs python3, pexpect, e2fsprogs, root for the loop mounts.
cd "$(dirname "$0")"; mkdir -p out; W=/tmp/budgets; umount $W/m 2>/dev/null; rm -rf $W; mkdir -p $W/m
{
echo '$ console_check.py "python3 fake_target.py" > boot.txt   # a scripted console, not a board'
python3 console_check.py "python3 fake_target.py" > $W/boot.txt
echo '$ check-budgets.py boot boot.txt Kernel=2 systemd=3 login=3'; ./check-budgets.py boot $W/boot.txt Kernel=2 systemd=3 login=3; echo "exit status $?"
echo '$ check-budgets.py boot boot.txt Kernel=1 login=1.5'; ./check-budgets.py boot $W/boot.txt Kernel=1 login=1.5; echo "exit status $?"
echo
for f in analyze-ok analyze-slow; do
  echo "\$ check-budgets.py analyze fixtures/$f.txt --max-kernel 5 --max-userspace 12"
  ./check-budgets.py analyze fixtures/$f.txt --max-kernel 5 --max-userspace 12; echo "exit status $?"
done
echo
for used in 700 1250; do
  img=$W/root$used.ext4; truncate -s 1536M $img; mke2fs -q -F -t ext4 -L rootA $img; mount -o loop $img $W/m; fallocate -l ${used}M $W/m/payload; umount $W/m
  echo "\$ check-budgets.py image root$used.ext4 --wks handbook-ab.wks --part rootA --max-used 75"
  ./check-budgets.py image $img --wks ../meta-handbook/wic/handbook-ab.wks --part rootA --max-used 75; echo "exit status $?"
done
img=$W/big.ext4; truncate -s 1600M $img; mke2fs -q -F -t ext4 -L rootA $img
echo '$ check-budgets.py image big.ext4 --wks handbook-ab.wks --part rootA --max-used 75   # image file larger than the slot'
./check-budgets.py image $img --wks ../meta-handbook/wic/handbook-ab.wks --part rootA --max-used 75; echo "exit status $?"
} > out/budgets.txt 2>&1
cat out/budgets.txt
