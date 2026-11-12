#!/usr/bin/env python3
"""Wait for each boot stage on a console and report the time at which it appeared.
Usage: console_check.py <command that opens the console> ; for a real board use: 'picocom -b 115200 /dev/ttyUSB0'"""
import sys, time, pexpect

STAGES = [
    ("PLM",       r"Platform Loader and Manager", 10),
    ("TF-A",      r"BL31: v[0-9.]+",              10),
    ("U-Boot",    r"U-Boot [0-9.]+",              10),
    ("Kernel",    r"Linux version [0-9.]+",       10),
    ("systemd",   r"Reached target Multi-User",   10),
    ("login",     r"login: ",                     10),
]

def main(cmd):
    child = pexpect.spawn(cmd, encoding="utf8", timeout=10)
    t0 = time.monotonic()
    for name, pattern, limit in STAGES:
        try:
            child.expect(pattern, timeout=limit)
        except pexpect.TIMEOUT:
            print(f"FAIL  {name:8s} not seen within {limit} s")
            print(f"      last output: {child.before[-60:].strip()!r}")
            return 1
        except pexpect.EOF:
            print(f"FAIL  {name:8s} console closed")
            return 1
        print(f"PASS  {name:8s} at {time.monotonic() - t0:5.2f} s")
    child.close(force=True)
    return 0

if __name__ == "__main__":
    sys.exit(main(" ".join(sys.argv[1:])))
