#!/usr/bin/env python3
"""Gate a cyclictest summary against a latency budget.

Usage: check-cyclictest.py <cyclictest-output.txt> --max-us 150 [--min-samples 3600000]
Reads the per-thread summary lines of 'cyclictest -q' (T: 0 ( pid) P:80 I:1000 C: n Min: Act: Avg: Max:).
A run with too few samples is not evidence, so it fails even if every maximum is inside the budget.
Exit status: number of failed checks.
"""
import re, sys

LINE = re.compile(r"T:\s*(\d+)\s*\(\s*\d+\)\s*P:\s*(\d+)\s*I:\s*(\d+)\s*C:\s*(\d+)\s*Min:\s*(\d+)\s*Act:\s*(\d+)\s*Avg:\s*(\d+)\s*Max:\s*(\d+)")

def main():
    args = sys.argv[1:]
    if not args or "--max-us" not in args:
        print(__doc__); return 64
    path = args[0]
    budget = int(args[args.index("--max-us") + 1])
    min_samples = int(args[args.index("--min-samples") + 1]) if "--min-samples" in args else 0
    threads = [tuple(int(x) for x in m.groups()) for m in map(LINE.search, open(path)) if m]
    if not threads:
        print("FAIL no cyclictest summary lines found"); return 1
    fails = 0
    for t, prio, interval, count, mn, act, avg, mx in threads:
        ok = mx <= budget
        print(f"{'PASS' if ok else 'FAIL'} thread {t} priority {prio} max {mx} us (budget {budget} us), average {avg} us")
        fails += not ok
    total = min(c for _, _, _, c, *_ in threads)
    ok = total >= min_samples
    print(f"{'PASS' if ok else 'FAIL'} samples per thread {total} (minimum {min_samples})")
    fails += not ok
    return fails

if __name__ == "__main__":
    sys.exit(main())
