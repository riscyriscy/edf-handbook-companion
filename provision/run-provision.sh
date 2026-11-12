#!/bin/bash
# Provision three units against a test PKI, then try four mistakes. Output goes to out/provision.txt.
# Needs openssl. The root file system is a directory with the keyring and system.conf of the companion layer.
cd "$(dirname "$0")"; mkdir -p out; W=/tmp/prov; rm -rf $W; mkdir -p $W/ca $W/ca2 $W/upd $W/upd2 $W/units; HERE=$PWD
mkca() { openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout $1/ca.key.pem -out $1/ca.cert.pem -subj "/O=Handbook Test/CN=$2" -days 3650 -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null; }
mkca $W/ca "Handbook Factory CA"; mkca $W/ca2 "Other Factory CA"
mkca $W/upd "Handbook Update CA"; mkca $W/upd2 "Another Update CA"
mkroot() { mkdir -p $1/etc/rauc; cp $2 $1/etc/rauc/ca.cert.pem; cp $HERE/../meta-handbook/recipes-update/rauc/files/system.conf $1/etc/rauc/system.conf; }
mkroot $W/rootfs $W/upd/ca.cert.pem; mkroot $W/rootfs-other $W/upd2/ca.cert.pem
WANT=$(sha256sum $W/upd/ca.cert.pem | cut -d" " -f1)   # the release record names the keyring digest
LEDGER=$W/ledger.csv
{
for s in HB000001 HB000002 HB000003; do
  echo "\$ provision-unit.sh units/$s $s ca ledger.csv"; ./provision-unit.sh $W/units/$s $s $W/ca $LEDGER
done
echo; echo '$ cat ledger.csv   # serial, SHA-256 of the certificate, time (certificate digits shortened)'
sed 's/,\([0-9A-F]\{12\}\)[0-9A-F]*,[^,]*$/,\1.../' $LEDGER
echo; echo '$ verify-unit.sh units/HB000002 ledger.csv rootfs <digest>'
./verify-unit.sh $W/units/HB000002 $LEDGER $W/rootfs $WANT; echo "exit status $?"
echo; echo "# Mistakes"
echo '$ provision-unit.sh units/HB000002b HB000002 ca ledger.csv       # same serial again'
./provision-unit.sh $W/units/HB000002b HB000002 $W/ca $LEDGER 2>&1; echo "exit status $?"
echo '$ provision-unit.sh units/x hb-7 ca ledger.csv                   # malformed serial'
./provision-unit.sh $W/units/x hb-7 $W/ca $LEDGER 2>&1; echo "exit status $?"
echo; echo '$ verify-unit.sh units/HB000003 ledger.csv rootfs-other <digest>   # flashed with an image that has another keyring'
./verify-unit.sh $W/units/HB000003 $LEDGER $W/rootfs-other $WANT | grep -v '^PASS'; echo "exit status ${PIPESTATUS[0]}"
echo; echo '$ verify-unit.sh units/HB000001 ledger.csv rootfs <digest>   # certificate signed by the wrong factory CA'
openssl x509 -req -in <(openssl req -new -key $W/units/HB000001/identity/device.key.pem -subj "/O=Handbook Test/CN=HB000001") -CA $W/ca2/ca.cert.pem -CAkey $W/ca2/ca.key.pem -CAcreateserial -out $W/units/HB000001/identity/device.cert.pem -days 3650 2>/dev/null
./verify-unit.sh $W/units/HB000001 $LEDGER $W/rootfs $WANT | grep -v '^PASS'; echo "exit status ${PIPESTATUS[0]}"
} > out/provision.txt 2>&1
cat out/provision.txt
