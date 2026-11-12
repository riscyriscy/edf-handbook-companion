#!/bin/bash
# Remote debugging with split debug symbols (chapter 8). Needs gcc, gdb, gdbserver, binutils.
# Part 1 runs gdbserver on the build host architecture. Part 2 debugs an aarch64 binary through the
# QEMU user mode gdb stub with gdb-multiarch (needs aarch64-linux-gnu-gcc, qemu-aarch64, gdb-multiarch).
set -u
HERE=$(cd "$(dirname "$0")" && pwd); W=$HERE/work; O=$HERE/out
rm -rf "$W" "$O"; mkdir -p "$W/dev" "$W/symbols" "$O"; cd "$W"
filt() { sed "s#$W/##g; s/process [0-9]*/process N/; s/pid = [0-9]*/pid = N/" | grep -v '^Remote debugging\|^warning\|^Reading\|^$\|^Download\|^Detaching\|^\[Inferior\|^Listening\|^Process .* created\|^Remote side\|^Child\|^qemu-aarch64: QEMU'; }
# split: stripped binary for the device, symbols filed by build id for the host
split() { # tool prefix: empty for the host, aarch64-linux-gnu- for the cross tools
  ${1}gcc -g -O0 -static -Wl,--build-id -fdebug-prefix-map=$HERE=. -o crash.full "$HERE/crash.c"
  id=$(${1}readelf -n crash.full | sed -n 's/.*Build ID: //p'); d=symbols/.build-id/${id:0:2}; mkdir -p $d
  ${1}objcopy --only-keep-debug crash.full $d/${id:2}.debug; ${1}objcopy --strip-all crash.full dev/crash; }
{
echo "# Part 1: gdbserver, build host architecture"
echo '$ gcc -g -O0 -static -Wl,--build-id -fdebug-prefix-map=$PWD=. -o crash.full crash.c'
echo '$ objcopy --only-keep-debug crash.full symbols/.build-id/xx/yyyy.debug   # to the host'
echo '$ objcopy --strip-all crash.full dev/crash                                 # to the device'
split ""; stat -c '%n %s bytes' crash.full dev/crash symbols/.build-id/*/*.debug | sed 's#symbols/.build-id/.*#symbols/.build-id/xx/yyyy.debug#' | sort -u
echo
echo '$ gdbserver --once localhost:2345 dev/crash arg1 &        # on the device'
gdbserver --once localhost:2345 dev/crash arg1 2>&1 | filt & sleep 1
echo '$ gdb -batch -ex "target remote localhost:2345" -ex continue -ex bt dev/crash   # no symbols on the host'
gdb -batch -nx -ex "target remote localhost:2345" -ex continue -ex bt dev/crash 2>&1 | filt | head -8; wait
echo
echo '$ gdbserver --once localhost:2346 dev/crash arg1 &'
gdbserver --once localhost:2346 dev/crash arg1 2>&1 | filt >/dev/null & sleep 1
echo '$ gdb -batch -iex "set debug-file-directory symbols" -ex "target remote localhost:2346" -ex continue -ex bt dev/crash'
gdb -batch -nx -iex "set debug-file-directory $W/symbols" -ex "target remote localhost:2346" -ex continue -ex bt dev/crash 2>&1 | filt | head -8; wait
echo
echo "# Part 2: aarch64 binary through the QEMU user mode gdb stub"
if command -v aarch64-linux-gnu-gcc >/dev/null && command -v qemu-aarch64 >/dev/null && command -v gdb-multiarch >/dev/null; then
  rm -rf dev symbols; mkdir dev symbols; split aarch64-linux-gnu-
  echo '$ qemu-aarch64 -g 2347 dev/crash arg1 &'
  qemu-aarch64 -g 2347 dev/crash arg1 2>&1 | filt & sleep 1
  echo '$ gdb-multiarch -batch -iex "set debug-file-directory symbols" -ex "target remote localhost:2347" -ex continue -ex bt -ex "info registers pc" dev/crash'
  gdb-multiarch -batch -nx -iex "set debug-file-directory $W/symbols" -ex "target remote localhost:2347" -ex continue -ex bt -ex "info registers pc" dev/crash 2>&1 | filt | head -10; wait
fi
} > "$O/gdbserver.txt" 2>&1
cat "$O/gdbserver.txt"
