#!/bin/bash
# Key rotation cases for chapter 12. Run run-lab.sh first: this script reuses its CA and bundles in ./work.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work; O=$HERE/out
clean() { LC_ALL=C sed "s/\x1b\[[0-9;]*m//g; s/[\x80-\xff]\+/ /g; s/\([0-9]\)?kB/\1 kB/; s#$W/##g" | grep -v '^rauc-Message\|^$\|central status\|system status'; }
cd "$W"
# 1. A second CA and signer (the "2027" generation)
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ca2.key.pem -out ca2.cert.pem \
  -subj "/O=Handbook Test/CN=Handbook Test CA 2027" -days 365 \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout dev2.key.pem -out dev2.csr \
  -subj "/O=Handbook Test/CN=Handbook Test Signer 2027" 2>/dev/null
openssl x509 -req -in dev2.csr -CA ca2.cert.pem -CAkey ca2.key.pem -CAcreateserial -out dev2.cert.pem -days 365 -extfile plain.ext 2>/dev/null
cat ca.cert.pem ca2.cert.pem > both.cert.pem
sed "s#^path=.*#path=$W/ca2.cert.pem#" sys-custom.conf > sys-ca2only.conf
sed "s#^path=.*#path=$W/both.cert.pem#" sys-custom.conf > sys-both.conf
# 2. Re-sign the existing plain bundle with the new key, keeping the payload
# rauc resign refuses to overwrite its output, so remove a bundle left by an earlier run, and stop on any error
rm -f plain-resigned.raucb
rauc resign --cert dev2.cert.pem --key dev2.key.pem --keyring ca.cert.pem --signing-keyring ca2.cert.pem plain.raucb plain-resigned.raucb >/dev/null 2>"$O/resign.err" \
  || { echo "rauc resign failed:"; cat "$O/resign.err"; exit 1; }
{ echo '$ rauc --conf sys-custom.conf info plain.raucb    (certificate chain in the signature)'
  rauc --conf sys-custom.conf info plain.raucb 2>&1 | clean | grep -i "Subject\|Issuer" | head -4
  echo; echo '$ rauc --conf sys-custom.conf info plain-resigned.raucb    (device trusts the old CA only)'
  rauc --conf sys-custom.conf info plain-resigned.raucb 2>&1 | clean | head -2
  echo; echo '$ rauc --conf sys-ca2only.conf info plain.raucb            (device trusts the new CA only)'
  rauc --conf sys-ca2only.conf info plain.raucb 2>&1 | clean | head -2
  echo; echo '$ rauc --conf sys-both.conf info plain.raucb               (keyring holds both CAs)'
  rauc --conf sys-both.conf info plain.raucb 2>&1 | clean | grep -i "Compatible\|Version\|Issuer" | head -3
  echo; echo '$ rauc --conf sys-ca2only.conf info plain-resigned.raucb    (device trusts the new CA only)'
  rauc --conf sys-ca2only.conf info plain-resigned.raucb 2>&1 | clean | grep -i "Compatible\|Version\|Issuer\|failed" | head -3
  echo; echo '$ rauc --conf sys-both.conf info plain-resigned.raucb'
  rauc --conf sys-both.conf info plain-resigned.raucb 2>&1 | clean | grep -i "Compatible\|Version\|Issuer" | head -3
  echo; echo '$ rauc --conf sys-both.conf info --output-format=json <bundle> | grep -o checksum and size'
  for f in plain.raucb plain-resigned.raucb; do
    printf '%-20s ' "$f"; rauc --conf sys-both.conf info --output-format=json "$f" 2>&1 | grep -o '"checksum":"[0-9a-f]*","size":[0-9]*'
  done
} > "$O/keys.txt"
echo "done: $O/keys.txt"
