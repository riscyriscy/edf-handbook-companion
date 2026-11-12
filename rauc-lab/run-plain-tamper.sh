#!/bin/bash
# Payload damage in a plain bundle and in a verity bundle (chapter 12). Run run-lab.sh first: this script reuses the keys and bundles in ./work.
# Needs rauc 1.11 or later. Writes out/plain-tamper.txt.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work; O=$HERE/out
clean() { LC_ALL=C sed "s/\x1b\[[0-9;]*m//g; s/[\x80-\xff]\+/ /g; s#$W/##g" | grep -v '^rauc-Message\|^$\|central status\|system status\|Reading\|Verifying'; }
cd "$W"
for fmt in plain update; do # plain.raucb is a plain bundle, update.raucb is a verity bundle
  cp $fmt.raucb tamper-$fmt-payload.raucb; printf '\x55' | dd of=tamper-$fmt-payload.raucb bs=1 seek=300000 conv=notrunc 2>/dev/null
done
{
  for b in plain update; do
    echo "# $(rauc --conf sys-custom.conf info $b.raucb 2>&1 | grep -m1 'Bundle Format' | sed 's/Bundle Format:[ \t]*//') bundle $b.raucb, one byte changed at offset 300000 of the payload"
    echo "\$ rauc --conf sys-custom.conf info tamper-$b-payload.raucb"
    rauc --conf sys-custom.conf info tamper-$b-payload.raucb 2>&1 | clean | head -1; echo
    echo "\$ rauc --conf sys-custom.conf extract tamper-$b-payload.raucb out-dir"
    rm -rf "$W/x"; rauc --conf sys-custom.conf extract tamper-$b-payload.raucb "$W/x" 2>&1 | clean | head -1; echo
  done
} > "$O/plain-tamper.txt"
cat "$O/plain-tamper.txt"
