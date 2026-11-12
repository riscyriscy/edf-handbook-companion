#!/bin/bash
# Factory provisioning of one unit against a test PKI (chapter 14). The directory <unit-dir> stands for the unit's data partition.
# Usage: provision-unit.sh <unit-dir> <serial> <factory-ca-dir> <ledger.csv>
# Step 1 runs on the unit (the key never leaves it). Step 2 runs at the station, where the factory CA key lives.
# Needs openssl. The CA here is a test CA created by run-provision.sh.
set -eu
unit=$1; serial=$2; ca=$3; ledger=$4
case "$serial" in [A-Z][A-Z][0-9][0-9][0-9][0-9][0-9][0-9]) ;; *) echo "bad serial format: $serial" >&2; exit 2;; esac
if [ -f "$ledger" ] && grep -q "^$serial," "$ledger"; then echo "serial $serial is already in the ledger" >&2; exit 3; fi
id=$unit/identity; mkdir -p "$id"; chmod 0700 "$id"
# 1. on the unit: key pair and certificate request
umask 077
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout "$id/device.key.pem" -out "$id/device.csr" -subj "/O=Handbook Test/CN=$serial" 2>/dev/null
echo "$serial" > "$id/serial"
# 2. at the station: check that the request names the serial, then sign
subj=$(openssl req -in "$id/device.csr" -noout -subject | sed -n 's/.*CN *= *//p')
[ "$subj" = "$serial" ] || { echo "request names $subj, not $serial" >&2; exit 4; }
printf 'basicConstraints=CA:FALSE\nkeyUsage=digitalSignature\nextendedKeyUsage=clientAuth\n' > "$id/ext.cnf"
openssl x509 -req -in "$id/device.csr" -CA "$ca/ca.cert.pem" -CAkey "$ca/ca.key.pem" -CAcreateserial -out "$id/device.cert.pem" -days 3650 -extfile "$id/ext.cnf" 2>/dev/null
rm -f "$id/ext.cnf" "$id/device.csr"
# 3. install the factory CA certificate, so that the unit can check its own chain. The update keyring is not written here:
#    it belongs to the root file system image and arrives with the flash image.
install -m 0644 "$ca/ca.cert.pem" "$id/factory-ca.cert.pem"
# 4. record the unit
fp=$(openssl x509 -in "$id/device.cert.pem" -noout -fingerprint -sha256 | sed 's/.*=//; s/://g')
echo "$serial,$fp,$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ledger"
echo "provisioned $serial"
