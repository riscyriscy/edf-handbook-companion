#!/bin/bash
# Build and check an authenticated Zynq UltraScale+ boot image with bootgen, using stand-in ELF files and test keys.
# Usage: run-secboot.sh <path to bootgen> [path to bootgen-bif.bbclass of meta-xilinx]. Writes the transcript to out/secboot.txt.
# The keys are for testing only. Never ship them or reuse them.
set -u
BOOTGEN=$(readlink -f "${1:?usage: run-secboot.sh <path to bootgen>}")
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d); cd "$W"
cp "$HERE"/*.bif "$HERE"/mkelf.py .
python3 mkelf.py fsbl.elf 0xFFFC0000 256; python3 mkelf.py atf.elf 0xFFFEA000 128; python3 mkelf.py u-boot.elf 0x8000000 512
bg() { "$BOOTGEN" -arch zynqmp "$@" 2>&1 | grep -v "^\*\*\*\|^  \*\*\*\|^    \*\*\|^$\|silicon 2.0\|zynqmpes1"; }
{
echo '$ bootgen -arch zynqmp -image keys.bif -generate_keys pem'
bg -image keys.bif -generate_keys pem; ls *.pem
echo
echo '$ bootgen -arch zynqmp -image auth.bif -w -o boot.bin -efuseppkbits efuseppksha.txt'
bg -image auth.bif -w -o boot.bin -efuseppkbits efuseppksha.txt
echo "boot.bin: $(stat -c %s boot.bin) bytes. PPK hash file: $(tr -dc '0-9A-F' < efuseppksha.txt | wc -c) hex digits"
echo
echo '$ bootgen -arch zynqmp -image auth.bif -verify boot.bin'
bg -image auth.bif -verify boot.bin | grep -c "Signature Verified" | sed 's/$/ signature checks passed (header, SPK and partitions)/'
bg -image auth.bif -verify boot.bin | tail -1
echo
if [ -n "${2:-}" ]; then
echo '# The same flags through the BIF writer of meta-xilinx (bootgen-bif.bbclass)'
python3 "$HERE/bif-from-class.py" "$2" gen.bif; cat gen.bif
echo '$ bootgen -arch zynqmp -image gen.bif -w -o gen.bin ; bootgen -arch zynqmp -image gen.bif -verify gen.bin'
bg -image gen.bif -w -o gen.bin | grep -v "^$"; bg -image gen.bif -verify gen.bin | tail -1
echo "sizes: boot.bin $(stat -c %s boot.bin) bytes, gen.bin $(stat -c %s gen.bin) bytes"
echo
fi
echo '# Flip one byte inside the u-boot partition, then verify again'
python3 - <<'PY'
d = bytearray(open("boot.bin", "rb").read())
i = d.rfind(bytes((i * 7 + 3) & 0xFF for i in range(64)))   # inside the stand-in u-boot payload
d[i + 10] ^= 0xFF
open("boot-tampered.bin", "wb").write(d)
PY
echo '$ bootgen -arch zynqmp -image auth.bif -verify boot-tampered.bin'
bg -image auth.bif -verify boot-tampered.bin | tail -4
echo
echo '# A new secondary key under the same primary key: the PPK hash does not change'
mkdir rot && cp auth.bif atf.elf u-boot.elf fsbl.elf primary.pem rot/
openssl genrsa -out rot/secondary.pem 4096 2>/dev/null
sed -i 's/spk_id=0x00000001/spk_id=0x00000002/' rot/auth.bif
(cd rot && "$BOOTGEN" -arch zynqmp -image auth.bif -w -o boot.bin -efuseppkbits efuseppksha.txt >/dev/null 2>&1)
echo '$ bootgen -arch zynqmp -image auth.bif -verify boot.bin    (secondary key 2, SPK ID 2)'
(cd rot && "$BOOTGEN" -arch zynqmp -image auth.bif -verify boot.bin 2>&1 | tail -1)
echo "hash, key set 1             : $(tr -dc '0-9A-F' < efuseppksha.txt)"
echo "hash, same primary, new SPK : $(tr -dc '0-9A-F' < rot/efuseppksha.txt)"
echo
echo '# A new primary key: the PPK hash changes'
mkdir second && cp keys.bif auth.bif fsbl.elf atf.elf u-boot.elf second/
(cd second && "$BOOTGEN" -arch zynqmp -image keys.bif -generate_keys pem >/dev/null 2>&1 && "$BOOTGEN" -arch zynqmp -image auth.bif -w -o boot.bin -efuseppkbits efuseppksha.txt >/dev/null 2>&1)
echo "hash, key set 2             : $(tr -dc '0-9A-F' < second/efuseppksha.txt)"
} > "$HERE/out/secboot.txt" 2>&1
cat "$HERE/out/secboot.txt"; rm -rf "$W"
