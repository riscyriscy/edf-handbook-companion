#!/bin/bash
# End of line check of a provisioned unit.
# Usage: verify-unit.sh <unit-dir> <ledger.csv> <rootfs-dir> <release-keyring-sha256>
# <rootfs-dir> is the unit's root file system as flashed (mounted read only at the station).
# Exit status: number of failed checks.
unit=$1; ledger=$2; rootfs=$3; want=$4; id=$unit/identity; fail=0
check() { label=$1; shift; if "$@" >/dev/null 2>&1; then echo "PASS $label"; else echo "FAIL $label"; fail=$((fail+1)); fi; }
serial=$(cat "$id/serial" 2>/dev/null)
check "serial file has the format" sh -c "echo '$serial' | grep -Eq '^[A-Z]{2}[0-9]{6}\$'"
check "certificate chains to the factory CA" openssl verify -CAfile "$id/factory-ca.cert.pem" "$id/device.cert.pem"
check "certificate subject is the serial" sh -c "openssl x509 -in '$id/device.cert.pem' -noout -subject | grep -q 'CN *= *$serial\$'"
check "private key matches the certificate" sh -c "[ \"\$(openssl pkey -in '$id/device.key.pem' -pubout 2>/dev/null)\" = \"\$(openssl x509 -in '$id/device.cert.pem' -noout -pubkey)\" ]"
check "private key file mode is 600" sh -c "[ \"\$(stat -c %a '$id/device.key.pem')\" = 600 ]"
check "release keyring digest is 64 hex digits" sh -c "echo '$want' | grep -Eq '^[0-9a-f]{64}\$'"
check "RAUC keyring in the image is the release keyring" sh -c "[ \"\$(sha256sum '$rootfs/etc/rauc/ca.cert.pem' | cut -d\" \" -f1)\" = '$want' ]"
check "system.conf points at that keyring" grep -qx "path=/etc/rauc/ca.cert.pem" "$rootfs/etc/rauc/system.conf"
check "ledger has this serial once, with this certificate" sh -c "[ \"\$(grep -c '^$serial,' '$ledger')\" = 1 ] && grep -q '^$serial,'\"\$(openssl x509 -in '$id/device.cert.pem' -noout -fingerprint -sha256 | sed 's/.*=//; s/://g')\" '$ledger'"
exit $fail
