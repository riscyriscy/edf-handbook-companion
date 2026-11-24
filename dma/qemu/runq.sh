#!/bin/bash
# Boots linux-xlnx 6.18.40 on the QEMU machine xlnx-zcu102 with two GDMA channels,
# the client handbook_dmacopy.c and dmatest, and keeps the lines about DMA.
cd "$(dirname "$0")"; mkdir -p out
for i in 1 2 3; do
  timeout 25 qemu-system-aarch64 -M xlnx-zcu102 -m 1G -nographic -serial mon:stdio \
    -kernel ${IMAGE:-Image} -dtb zcu102-dma.dtb -initrd initramfs.cpio.gz 2>/dev/null > out/raw$i.txt
  grep -a -E "dmatest|dmacopy|^init: |^  dma" out/raw$i.txt | sed 's/^\[[ 0-9.]*\] //' > out/run$i.txt
done
