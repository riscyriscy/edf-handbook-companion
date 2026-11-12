#!/bin/bash
# Chapter 14: build, check, change and write a board identity EEPROM image (made up product data).
# Needs python3 and cmp. ipmi-fru from freeipmi is used as a second, independent decoder when it is present.
# Run in this directory:  ./run-board-id.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d)
cd "$W"
# fru ARGS: run fruimg.py in the scratch directory and print the command, its output and its exit status
fru() { echo "\$ fruimg.py $*"; python3 "$HERE/fruimg.py" "$@" 2>&1; echo "exit status $?"; echo; }

echo "# 1. Build an image for a new unit, then check it and show its layout"
fru build -o som.bin --serial SN0000001 --mac 02:00:00:00:00:01
fru show som.bin
fru check som.bin

echo "# 2. The same bytes through an independent decoder (freeipmi, the library that xmutil uses)"
if command -v ipmi-fru > /dev/null; then
    echo "\$ ipmi-fru --fru-file=som.bin | grep -E 'Manufacturer|Product|Serial|Part|Custom Info: A1|OEM Manufacturer ID'"
    ipmi-fru --fru-file=som.bin 2>&1 | grep -E 'Manufacturer|Product|Serial|Part|Custom Info: A1|OEM Manufacturer ID'
    echo
fi

echo "# 3. What U-Boot puts in its environment from this image"
fru uboot som.bin

echo "# 4. Change the serial number and the MAC address, and see which bytes moved"
fru set som.bin -o som2.bin --serial SN0000002 --mac 02:00:00:00:00:02
fru diff som.bin som2.bin
fru check som2.bin

echo "# 5. Write the image to the EEPROM and read it back. A file of 8192 bytes stands for the M24C64."
echo "\$ head -c 8192 /dev/zero | tr '\\0' '\\377' > eeprom.img   (an erased EEPROM reads 0xFF)"
head -c 8192 /dev/zero | tr '\0' '\377' > eeprom.img
echo "\$ dd if=som.bin of=eeprom.img bs=32 conv=notrunc"
dd if=som.bin of=eeprom.img bs=32 conv=notrunc 2>&1 | sed -E 's/, [0-9.e-]+ s, .*//'
echo "\$ dd if=eeprom.img of=readback.bin bs=256 count=1 && cmp som.bin readback.bin"
dd if=eeprom.img of=readback.bin bs=256 count=1 2>/dev/null && cmp som.bin readback.bin && echo "readback equals the image"
echo "\$ dd if=som2.bin of=eeprom.img bs=32 conv=notrunc; read back and compare with som2.bin"
dd if=som2.bin of=eeprom.img bs=32 conv=notrunc 2>/dev/null
dd if=eeprom.img of=readback.bin bs=256 count=1 2>/dev/null && cmp som2.bin readback.bin && echo "readback equals the image"
fru check readback.bin

echo "# 6. Faults that the check finds"
echo "## one byte of the serial number changed without a new checksum"
cp som.bin bad1.bin
printf '\x39' | dd of=bad1.bin bs=1 seek=$((0x29)) conv=notrunc 2>/dev/null
fru check bad1.bin
echo "## the last byte of the MAC address changed without a new checksum"
cp som.bin bad2.bin
printf '\x7f' | dd of=bad2.bin bs=1 seek=$((0x7A + 14)) conv=notrunc 2>/dev/null
fru check bad2.bin
echo "## an image cut off after the board info area"
head -c 104 som.bin > bad3.bin
fru check bad3.bin
echo "## an erased EEPROM (all bytes 0xFF)"
head -c 256 /dev/zero | tr '\0' '\377' > bad4.bin
fru check bad4.bin
cd "$HERE" && rm -rf "$W"
