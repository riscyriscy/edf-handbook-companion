#!/usr/bin/env python3
"""Check the files of a recovered file system against the pattern. Prints: synced_acked ok_synced bad_synced plain_found plain_complete plain_short
Usage: verify.py <mountpoint> <ack-log>"""
import os, sys
mnt, ack = sys.argv[1], sys.argv[2]
acked = [l.strip() for l in open(ack) if l.strip()]
def state(d, n):
    p = os.path.join(mnt, d, n)
    if not os.path.exists(p): return "missing"
    b = open(p, "rb").read()
    return "ok" if b == (b"%08d" % int(n)) * 8192 else "bad"
ok = sum(state("synced", n) == "ok" for n in acked)
bad = len(acked) - ok
names = sorted(os.listdir(os.path.join(mnt, "plain")))
comp = sum(state("plain", n) == "ok" for n in names)
print(len(acked), ok, bad, len(names), comp, len(names) - comp)
