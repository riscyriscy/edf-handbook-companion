# Test sequence inside the guest. Prints the commands and their output.
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
clean() { sed -e 's/\x1b\[[0-9;]*m//g' | grep -v '^$\|central status\|system status\|% Reading\|Verifying\|rauc-Message'; }
bl() { echo "boot state: $(tr '\n' ' ' < /tmp/bl-state)"; }
written() { sync; awk '{print $7 * 512}' /sys/block/vdb/stat; }
inst() { echo; echo "\$ rauc install $1    $2"; w0=$(written); rauc --conf sys.conf install $1 2>&1 | clean | grep "LastError\|^Installing "; echo "bytes written to slot B: $(( $(written) - w0 ))"; }
same() { if cmp -s /dev/vdb $1; then echo "slot B equals $1"; else echo "slot B differs from $1: $(cmp /dev/vdb $1 2>&1 | head -1)"; fi; }
(rauc --conf sys.conf service --override-boot-slot=A >/tmp/service.log 2>&1 &); sleep 3
echo "# device-mapper in the guest: /dev/mapper/$(ls /dev/mapper), module $(grep -o '^dm_verity' /proc/modules) loaded"
inst v2n.raucb "(verity bundle, full image)"; same img2; bl
echo; echo "# A. Damaged bundles"
inst tamper-sig.raucb "(one byte changed in the signature)" 3; bl; same img2
inst tamper-payload.raucb "(release 4 image, which shares no block with slot B; one byte changed at offset 300000 of the bundle)" 3; bl
echo "# slot B against release 4 (the new image): $(cmp /dev/vdb img4 2>&1 | head -1)"
echo "# slot B against release 2 (the old image): $(cmp /dev/vdb img2 2>&1 | head -1)"
echo "# B. Adaptive bundles (block-hash-index); the slot is the source of the blocks that did not change"
inst v1.raucb "(adaptive, slot B holds the mix left by the failed install)" 4; same img1
inst v2.raucb "(adaptive, 8 blocks of 4 KiB differ from the slot)" 4; same img2
echo "# C. One block of the slot damaged where the index points to it"
printf '\x55' | dd of=/dev/vdb bs=1 seek=$((100*4096+7)) conv=notrunc 2>/dev/null
same img2
inst v3.raucb "(adaptive, 4 blocks differ, block 100 of the slot is damaged)" 4; same img3

echo; echo "# D. Streaming from a web server (bytes fetched are counted by the server)"
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up; route add default gw 10.0.2.2
echo "--stream-start"
inst http://10.0.2.2:8099/v2n.raucb "(verity bundle, no adaptive mode, over HTTP)"; same img2
echo "--stream-mid"
inst http://10.0.2.2:8099/v3.raucb "(adaptive bundle, over HTTP; slot B holds release 2, 4 blocks differ)"; same img3
echo "--stream-end"
echo; echo "# E. Streaming over HTTPS with the unit certificate (mutual TLS); each case restarts the RAUC service with its own configuration"
echo "# The streaming helper runs as the sandbox user nobody (uid 65534), so the files named by tls-cert and tls-key must be readable by that user"
own() { chown 65534 /lab/tls/$1.key.pem; chmod 0600 /lab/tls/$1.key.pem; chmod 0644 /lab/tls/$1.cert.pem; }
tlsinst() { kill $(pidof rauc); sleep 2; (rauc --conf $1 service --override-boot-slot=A >/tmp/service.log 2>&1 &); sleep 3
  echo; echo "\$ rauc --conf $1 install https://10.0.2.2:8443/v2.raucb    $2"; w0=$(written)
  rauc --conf $1 install https://10.0.2.2:8443/v2.raucb 2>&1 | clean | grep "LastError\|^Installing " | cut -c1-230
  grep -a -m1 "request failed" /tmp/service.log | sed -e 's/\x1b\[[0-9;]*m//g; s/^[^ ]* [^ ]* //'; echo "bytes written to slot B: $(( $(written) - w0 ))"; }
ls -ln /lab/tls/device.cert.pem /lab/tls/device.key.pem | awk '{print "as provisioned: " $1 " owner " $3 " " $NF}'
own wrong
tlsinst sys-nocert.conf "(the server is trusted, no client certificate)"
tlsinst sys-wrong.conf "(client certificate signed by another factory CA)"
tlsinst sys-tls.conf "(unit certificate HB000001, files as provisioned)"
own device; ls -ln /lab/tls/device.cert.pem /lab/tls/device.key.pem | awk '{print "readable by nobody: " $1 " owner " $3 " " $NF}'
tlsinst sys-tls.conf "(unit certificate HB000001, files readable by the sandbox user)"; same img2
