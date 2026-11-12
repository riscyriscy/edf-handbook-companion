#!/bin/bash
# Run handbook-rpu against a scripted stand-in for the remoteproc sysfs tree. Needs only sh and python3.
HERE=$(cd "$(dirname "$0")" && pwd)
RPU=$HERE/../meta-handbook/recipes-rpu/handbook-rpu/files/handbook-rpu
T=$(mktemp -d); mkdir "$T/fw"; cp "$HERE/../meta-handbook/recipes-rpu/handbook-rpu/files/handbook-rpu0.elf" "$T/fw/"
export RPROC_ROOT=$T/sys FW_DIR=$T/fw RPU_TIMEOUT=2
fail=0
run() {   # run <description> <initial state> <mode> <expected exit status> <command...>
    local what=$1 init=$2 mode=$3 want=$4; shift 4
    rm -rf "$T/sys"; python3 "$HERE/fake_remoteproc.py" "$T/sys" "$init" "$mode" >/dev/null & local pid=$!
    while [ ! -e "$T/sys/remoteproc0/state" ]; do sleep 0.05; done; sleep 0.1
    out=$("$@" 2>&1); got=$?
    kill $pid 2>/dev/null; wait $pid 2>/dev/null
    if [ "$got" = "$want" ]; then echo "PASS $what (exit $got)"; else echo "FAIL $what (exit $got, wanted $want)"; fail=$((fail+1)); fi
    [ -n "$out" ] && echo "     $out"
}
run "start from offline"            offline ok   0 sh "$RPU" start
run "start when already running"    running ok   0 sh "$RPU" start
run "start from crashed"            crashed ok   0 sh "$RPU" start
run "core that never comes up"      offline hang 5 sh "$RPU" start
run "stop a running core"           running ok   0 sh "$RPU" stop
run "status of a running core"      running ok   0 sh "$RPU" status
run "status of an offline core"     offline ok   1 sh "$RPU" status
FW_DIR=$T/none run "firmware file missing"  offline ok   3 sh "$RPU" start
RPU_MATCH=r5f_9 run "no core matches"       offline ok   2 sh "$RPU" start
echo "failures: $fail"
rm -rf "$T"; exit $fail
