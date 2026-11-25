#!/bin/bash
# Build and check an authenticated Versal PDI with bootgen, using stand-in ELF and CDO files and test keys.
# Usage: run-secboot-versal.sh <path to bootgen>. Writes the transcript to out/secboot-versal.txt.
# The keys are for testing only. Never ship them or reuse them.
set -u
BOOTGEN=$(readlink -f "${1:?usage: run-secboot-versal.sh <path to bootgen>}")
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d); cd "$W"
cp "$HERE"/auth-versal.bif "$HERE"/keys-versal.bif "$HERE"/mkelf.py .
python3 mkelf.py plm.elf 0xF0200000 256; python3 mkelf.py u-boot.elf 0x8000000 512
printf 'write 0xF1110000 0x00000001\nwrite 0xF1110004 0x00000002\n' > pmc_cdo.txt
printf 'write 0xFD1A0000 0x00000001\nwrite 0xFD1A0004 0x00000002\n' > fpd_cdo.txt
bg() { "$BOOTGEN" -arch versal "$@" 2>&1 | grep -v "^\*\*\*\|^  \*\*\*\|^    \*\*\|^$\|^-----\|id_code is not specified"; }
{
echo '$ bootgen -arch versal -image keys-versal.bif -generate_keys pem'
bg -image keys-versal.bif -generate_keys pem; ls *.pem
echo
echo '$ bootgen -arch versal -image auth-versal.bif -w -o boot.pdi -efuseppkbits efuseppksha.txt'
bg -image auth-versal.bif -w -o boot.pdi -efuseppkbits efuseppksha.txt
echo "boot.pdi: $(stat -c %s boot.pdi) bytes. PPK hash file: $(tr -dc '0-9A-F' < efuseppksha.txt | wc -c) hex digits"
echo
echo '$ bootgen -arch versal -image auth-versal.bif -verify boot.pdi'
bg -image auth-versal.bif -verify boot.pdi
echo "$(bg -image auth-versal.bif -verify boot.pdi | grep -c 'Signature Verified') signature checks passed"
echo
echo '# The same BIF without the metaheader line: the header is not signed'
sed '/metaheader/d' auth-versal.bif > auth-nohdr.bif
bg -image auth-nohdr.bif -w -o boot-nohdr.pdi >/dev/null
echo '$ bootgen -arch versal -image auth-nohdr.bif -verify boot-nohdr.pdi'
bg -image auth-nohdr.bif -verify boot-nohdr.pdi | grep 'WARNING\|^Authentication'
echo "$(bg -image auth-nohdr.bif -verify boot-nohdr.pdi | grep -c 'Signature Verified') signature checks passed"
echo
tamper() { # file pattern-size out
python3 - "$@" <<'PY'
import sys
src, pat, out = sys.argv[1], sys.argv[2], sys.argv[3]
d = bytearray(open(src, "rb").read())
i = d.rfind(bytes((i * 7 + 3) & 0xFF for i in range(64)))
if pat == "plm":
    i = d.find(bytes((i * 7 + 3) & 0xFF for i in range(64)))   # first stand-in payload is the PLM
d[i + 10] ^= 0xFF
open(out, "wb").write(d)
PY
}
echo '# Flip one byte inside the u-boot partition, then verify again'
tamper boot.pdi uboot boot-tampered.pdi
echo '$ bootgen -arch versal -image auth-versal.bif -verify boot-tampered.pdi'
bg -image auth-versal.bif -verify boot-tampered.pdi | tail -4
echo
echo '# Flip one byte inside the PLM partition, then verify again'
tamper boot.pdi plm boot-tampered-plm.pdi
echo '$ bootgen -arch versal -image auth-versal.bif -verify boot-tampered-plm.pdi'
bg -image auth-versal.bif -verify boot-tampered-plm.pdi | tail -5
echo
echo '# A new secondary key under the same primary key: the PPK hash does not change'
mkdir rot && cp auth-versal.bif plm.elf u-boot.elf pmc_cdo.txt fpd_cdo.txt primary0.pem rot/
openssl genrsa -out rot/secondary0.pem 4096 2>/dev/null
(cd rot && "$BOOTGEN" -arch versal -image auth-versal.bif -w -o boot.pdi -efuseppkbits efuseppksha.txt >/dev/null 2>&1)
echo '$ bootgen -arch versal -image auth-versal.bif -verify boot.pdi    (new secondary key)'
(cd rot && "$BOOTGEN" -arch versal -image auth-versal.bif -verify boot.pdi 2>&1 | tail -1)
echo "hash, key set 1             : $(tr -dc '0-9A-F' < efuseppksha.txt)"
echo "hash, same primary, new SSK : $(tr -dc '0-9A-F' < rot/efuseppksha.txt)"
echo
echo '# A new primary key: the PPK hash changes'
mkdir second && cp keys-versal.bif auth-versal.bif plm.elf u-boot.elf pmc_cdo.txt fpd_cdo.txt second/
(cd second && "$BOOTGEN" -arch versal -image keys-versal.bif -generate_keys pem >/dev/null 2>&1 && "$BOOTGEN" -arch versal -image auth-versal.bif -w -o boot.pdi -efuseppkbits efuseppksha.txt >/dev/null 2>&1)
echo "hash, key set 2             : $(tr -dc '0-9A-F' < second/efuseppksha.txt)"
echo
echo '# Verify the key set 1 image with key set 2 files'
echo '$ bootgen -arch versal -image auth-versal.bif -verify ../boot.pdi    (key set 2 directory)'
(cd second && "$BOOTGEN" -arch versal -image auth-versal.bif -verify ../boot.pdi 2>&1 | grep "^Authentication")
} > "$HERE/out/secboot-versal.txt" 2>&1
cat "$HERE/out/secboot-versal.txt"; rm -rf "$W"
