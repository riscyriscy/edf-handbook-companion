#!/bin/sh
# Check a kernel .config (or a merged config fragment) for a PREEMPT_RT latency build.
# Usage: check-rt-config.sh <.config>     Exit status: number of failed checks.
cfg=$1
[ -f "$cfg" ] || { echo "usage: $0 <.config>" >&2; exit 64; }
fail=0
want() { if grep -q "^$1=y" "$cfg"; then echo "PASS $1=y"; else echo "FAIL $1 is not set to y"; fail=$((fail + 1)); fi; }
avoid() { if grep -q "^$1=y" "$cfg"; then echo "FAIL $1=y adds latency or overhead on the real time path"; fail=$((fail + 1)); else echo "PASS $1 is off"; fi; }
want CONFIG_PREEMPT_RT
want CONFIG_HIGH_RES_TIMERS
if grep -q "^CONFIG_NO_HZ_FULL=y\|^CONFIG_NO_HZ_IDLE=y" "$cfg"; then echo "PASS tickless idle or full"; else echo "FAIL neither CONFIG_NO_HZ_IDLE nor CONFIG_NO_HZ_FULL"; fail=$((fail + 1)); fi
for s in CONFIG_PROVE_LOCKING CONFIG_LOCKDEP CONFIG_DEBUG_PREEMPT CONFIG_KASAN CONFIG_DEBUG_ATOMIC_SLEEP; do avoid $s; done
exit $fail
