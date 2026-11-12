#!/bin/sh
# Check the watchdog and failure policy in an unpacked root file system (for example the rootfs directory of a build).
# Usage: check-watchdog-policy.sh <rootfs-dir>
# Needs systemd-analyze on the host. Exit status: number of failed checks.
root=$1
[ -d "$root" ] || { echo "usage: $0 <rootfs-dir>" >&2; exit 64; }
fail=0
check() { # check <label> <command...>
    label=$1; shift
    if "$@" >/dev/null 2>&1; then echo "PASS $label"; else echo "FAIL $label"; fail=$((fail + 1)); fi
}
cfg=$(systemd-analyze cat-config --root="$root" systemd/system.conf 2>/dev/null)
value() { echo "$cfg" | sed -n "s/^$1=//p" | tail -n 1; }
rt=$(value RuntimeWatchdogSec); rb=$(value RebootWatchdogSec)
echo "effective RuntimeWatchdogSec=${rt:-unset} RebootWatchdogSec=${rb:-unset}"
check "RuntimeWatchdogSec is set and not 0 or off" sh -c "[ -n '$rt' ] && [ '$rt' != 0 ] && [ '$rt' != off ]"
check "RebootWatchdogSec is set" test -n "$rb"
for u in "$root"/usr/lib/systemd/system/*health*.service "$root"/etc/systemd/system/*health*.service; do
    [ -f "$u" ] || continue
    check "$(basename "$u") has FailureAction=reboot" grep -q '^FailureAction=reboot' "$u"
done
exit $fail
