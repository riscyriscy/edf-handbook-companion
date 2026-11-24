#!/bin/sh
# Check the diagnostics policy in an unpacked root file system: persistent journal, core dump limits, pstore archive.
# Usage: check-diag-policy.sh <rootfs-dir>
# Needs systemd-analyze on the host. Exit status: number of failed checks.
root=$1
[ -d "$root" ] || { echo "usage: $0 <rootfs-dir>" >&2; exit 64; }
fail=0
check() { # check <label> <command...>
    label=$1; shift
    if "$@" >/dev/null 2>&1; then echo "PASS $label"; else echo "FAIL $label"; fail=$((fail + 1)); fi
}
val() { # val <config> <key>  -> last effective value
    systemd-analyze cat-config --root="$root" "$1" 2>/dev/null | sed -n "s/^$2=//p" | tail -n 1
}
js=$(val systemd/journald.conf Storage)
echo "effective journald Storage=${js:-unset}"
check "journald Storage=persistent" test "$js" = persistent
check "journald SystemMaxUse is set" test -n "$(val systemd/journald.conf SystemMaxUse)"
# A persistent journal needs /var/log on persistent storage. A link into /var/volatile means it does not survive a reboot.
if [ -L "$root/var/log" ]; then
    echo "FAIL /var/log is a link to $(readlink "$root/var/log"); remove files/fs-perms-volatile-log.txt from FILESYSTEM_PERMS_TABLES"; fail=$((fail + 1))
else echo "PASS /var/log is a directory"; fi
for k in ProcessSizeMax ExternalSizeMax MaxUse KeepFree; do
    check "coredump $k is set" test -n "$(val systemd/coredump.conf $k)"
done
check "pstore archive removes files after copy (Unlink=yes)" test "$(val systemd/pstore.conf Unlink)" = yes
exit $fail
