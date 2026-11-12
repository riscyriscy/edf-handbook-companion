#!/usr/bin/env python3
"""A scripted stand-in for a board console. It prints a boot log with delays, so the console checker can be tested."""
import sys, time
LOG = [
    (0.1, "Xilinx Versal Platform Loader and Manager"),
    (0.2, "PLM Initialization Time"),
    (0.2, "NOTICE:  BL31: v2.14 running at EL3"),
    (0.3, "U-Boot 2026.01 (Jan 05 2026)"),
    (0.2, "Hit any key to stop autoboot:  0"),
    (0.5, "[    0.000000] Linux version 6.18.10-xilinx"),
    (0.4, "[    3.912004] systemd[1]: Reached target Multi-User System."),
    (0.1, "amd-edf login: "),
]
fail_at = sys.argv[1] if len(sys.argv) > 1 else ""
for delay, line in LOG:
    time.sleep(delay)
    if fail_at and fail_at in line:
        sys.stdout.write("Kernel panic - not syncing: VFS: Unable to mount root fs\n"); sys.stdout.flush()
        time.sleep(30)
    print(line, flush=True)
time.sleep(30)
