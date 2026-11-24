#!/bin/bash
# LUKS2 header and key slot checks for the encrypted data partition of Chapter 10.
# Needs cryptsetup 2.7 or later. Works on image files and needs no device mapper:
# --test-passphrase opens the key slot in user space and creates no mapping.
# Writes out/luks.txt. The key files are test keys; never copy them into a product.
set -u
cd "$(dirname "$0")"; mkdir -p out
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
{
echo "\$ cryptsetup --version"; cryptsetup --version
head -c 64 /dev/urandom > "$W/key.bin"; head -c 64 /dev/urandom > "$W/wrong.bin"
for case in default pbkdf2; do
  truncate -s 64M "$W/$case.img"
  if [ $case = default ]; then opts=""; else opts="--pbkdf pbkdf2 --pbkdf-force-iterations 1000"; fi
  echo "\$ cryptsetup luksFormat --batch-mode --type luks2 --key-file key.bin ${opts:+$opts }$case.img"
  cryptsetup luksFormat --batch-mode --type luks2 --key-file "$W/key.bin" $opts "$W/$case.img"; echo "exit status $?"
  echo "\$ cryptsetup luksDump $case.img   (selected lines)"
  cryptsetup luksDump "$W/$case.img" | awk '/^Data segments:/{s="seg"} /^Keyslots:/{s="key"} /^Tokens:/{s=""}
    s=="seg" && /^\t(offset|cipher|sector):/ {sub(/^\t/,"  data "); print}
    s=="key" && /^\t(PBKDF|Time cost|Memory|Iterations):/ {sub(/^\t/,"  key slot "); print}' | tr -s ' \t' ' '
  echo "\$ cryptsetup open --test-passphrase --key-file key.bin $case.img"
  s=$(date +%s%N); cryptsetup open --test-passphrase --key-file "$W/key.bin" "$W/$case.img"; e=$?; t=$(date +%s%N)
  echo "exit status $e, $(( (t - s) / 1000000 )) ms"
done
echo "\$ cryptsetup open --test-passphrase --key-file wrong.bin pbkdf2.img"
cryptsetup open --test-passphrase --key-file "$W/wrong.bin" "$W/pbkdf2.img" 2>&1; echo "exit status $?"
} > out/luks.txt 2>&1
cat out/luks.txt
