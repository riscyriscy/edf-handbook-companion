#!/bin/bash
# Builds what qemu/runq.sh boots: linux-xlnx at the revision that EDF 26.11 pins, with the
# client handbook_dmacopy.c built in, the device tree and an initramfs with init.c.
# Needs git, gcc-aarch64-linux-gnu, bc, bison, flex, cpio and about 2 GB of disk.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=${1:-$here/work}
rev=85261a88dc955839e3dabe5339b3a8d86ec545db   # SRCREV of linux-xlnx_6.18.40-v2026.2.bb
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
mkdir -p "$work"; cd "$work"
if [ ! -d linux ]; then
  git init -q linux
  git -C linux fetch -q --depth=1 https://github.com/Xilinx/linux-xlnx.git $rev
  git -C linux checkout -q FETCH_HEAD
fi
cd linux
cp "$here/../handbook_dmacopy.c" drivers/dma/
grep -q handbook_dmacopy drivers/dma/Makefile || echo 'obj-y += handbook_dmacopy.o' >> drivers/dma/Makefile
make -s allnoconfig
./scripts/config -e ARCH_ZYNQMP -e PRINTK -e TTY -e SERIAL_XILINX_PS_UART -e SERIAL_XILINX_PS_UART_CONSOLE \
  -e BLK_DEV_INITRD -e DEVTMPFS -e DEVTMPFS_MOUNT -e BINFMT_ELF -e PROC_FS -e SYSFS -e MULTIUSER -e MODULES \
  -e DMADEVICES -e DMA_ENGINE -e XILINX_ZYNQMP_DMA -e DMATEST -e COMMON_CLK -e OF -e PM -e ARM_ARCH_TIMER
make -s olddefconfig
make -s -j"$(nproc)" Image
cp arch/arm64/boot/Image "$here/Image"
cpp -nostdinc -I include -I scripts/dtc/include-prefixes -undef -x assembler-with-cpp \
  "$here/zcu102-dma.dts" | scripts/dtc/dtc -q -I dts -O dtb -o "$here/zcu102-dma.dtb" -
cd "$work"; rm -rf rootfs; mkdir -p rootfs/sys rootfs/dev
aarch64-linux-gnu-gcc -static -Os -Wall -o rootfs/init "$here/init.c"
(cd rootfs && find . | cpio -o -H newc 2>/dev/null | gzip) > "$here/initramfs.cpio.gz"
echo "built Image, zcu102-dma.dtb and initramfs.cpio.gz in $here"
