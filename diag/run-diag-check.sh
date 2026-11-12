#!/bin/bash
# Check the diagnostics recipe output and the ramoops node. Output goes to out/diag_check.txt.
# Needs systemd-analyze, dtc and python3. The root directory is built by running the recipe's install commands.
cd "$(dirname "$0")"; mkdir -p out; R=/tmp/diag-root; rm -rf $R
F=../meta-handbook/recipes-core/handbook-diag/files
install -d $R/etc/systemd/{journald,coredump,pstore}.conf.d $R/var
install -m 0644 $F/10-handbook-journald.conf $R/etc/systemd/journald.conf.d/
install -m 0644 $F/10-handbook-coredump.conf $R/etc/systemd/coredump.conf.d/
install -m 0644 $F/10-handbook-pstore.conf $R/etc/systemd/pstore.conf.d/
{
  echo '$ check-diag-policy.sh rootfs   # /var/log is a directory'; mkdir -p $R/var/log
  ../ci/check-diag-policy.sh $R; echo "exit status $?"; echo
  echo '$ check-diag-policy.sh rootfs   # /var/log links to /var/volatile/log (the Poky default)'
  rmdir $R/var/log; ln -s volatile/log $R/var/log
  ../ci/check-diag-policy.sh $R; echo "exit status $?"; echo
  dtc -q -I dts -O dtb -o /tmp/diag-top.dtb stub-top.dts
  echo '$ dtc -I dts -O dtb -o top.dtb stub-top.dts && check-rpu-memory.py top.dtb'
  python3 ../rpu/check-rpu-memory.py /tmp/diag-top.dtb; echo "exit status $?"
} > out/diag_check.txt 2>&1
cat out/diag_check.txt
