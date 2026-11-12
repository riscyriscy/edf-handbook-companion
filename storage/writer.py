#!/usr/bin/env python3
"""Write files into two directories of a mounted file system until killed.
synced/NNNNN gets 64 KiB, fsync of the file, then an fsync of the directory, and only then an entry in the ack log.
plain/NNNNN gets 64 KiB with no fsync.
Each file holds a repeating pattern derived from its number, so a reader can tell a complete file from a damaged one.
Usage: writer.py <mountpoint> <ack-log>"""
import os, sys
mnt, ack = sys.argv[1], sys.argv[2]
for d in ("synced", "plain"):
    os.makedirs(os.path.join(mnt, d), exist_ok=True)
fd0 = os.open(mnt, os.O_RDONLY); os.fsync(fd0)
log = open(ack, "a", buffering=1)
i = 0
while i < 3000:
    data = (b"%08d" % i) * 8192
    for d, sync in (("synced", True), ("plain", False)):
        p = os.path.join(mnt, d, "%05d" % i)
        fd = os.open(p, os.O_WRONLY | os.O_CREAT, 0o644)
        try:
            os.write(fd, data)
        except OSError:
            sys.exit(0)
        if sync:
            os.fsync(fd)
        os.close(fd)
        if sync:
            dfd = os.open(os.path.join(mnt, d), os.O_RDONLY); os.fsync(dfd); os.close(dfd)
            log.write("%05d\n" % i); log.flush(); os.fsync(log.fileno())
    i += 1
