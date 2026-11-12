#!/usr/bin/env python3
"""Check boot time and image size against budgets. Exit status: number of failed checks.

  check-budgets.py boot <console_check.py output> Kernel=6 systemd=12 login=15
      Each argument is a stage name and the latest time in seconds at which it may appear.
  check-budgets.py analyze <systemd-analyze time output> --max-kernel 5 --max-userspace 12
  check-budgets.py image <ext4 image> --wks <file.wks> --part rootA --max-used 75
      The image file must fit the partition in the WKS file, and its used blocks must stay under the percentage,
      so that later releases still fit the slot, which cannot grow after the first device ships.
Needs dumpe2fs for the image check.
"""
import re, subprocess, sys

def res(ok, text):
    print(("PASS " if ok else "FAIL ") + text); return 0 if ok else 1

def seconds(s):
    m = re.fullmatch(r"([\d.]+)(ms|s|min)", s)
    v = float(m.group(1)); return v / 1000 if m.group(2) == "ms" else v * 60 if m.group(2) == "min" else v

def boot(args):
    seen = {m.group(1): float(m.group(2)) for l in open(args[0]) if (m := re.match(r"PASS\s+(\S+)\s+at\s+([\d.]+) s", l))}
    fails = 0
    for a in args[1:]:
        name, limit = a.split("="); limit = float(limit)
        if name not in seen: fails += res(False, f"{name} was not seen"); continue
        fails += res(seen[name] <= limit, f"{name} at {seen[name]:.2f} s (budget {limit:g} s)")
    return fails

def analyze(args):
    txt = open(args[0]).read(); first = next(l for l in txt.splitlines() if l.startswith("Startup finished"))
    m = re.search(r"Startup finished in (.*?)(?: = ([\d.]+(?:ms|s|min)))?\s*$", first)
    parts = {name: seconds(v) for v, name in re.findall(r"([\d.]+(?:ms|s|min)) \((\w+)\)", first)}
    fails = 0
    for key, flag in (("kernel", "--max-kernel"), ("userspace", "--max-userspace")):
        if flag in args:
            limit = float(args[args.index(flag) + 1])
            fails += res(key in parts and parts[key] <= limit, f"{key} {parts.get(key, float('nan')):.2f} s (budget {limit:g} s)")
    return fails

def image(args):
    img = args[0]; wks = args[args.index("--wks") + 1]; part = args[args.index("--part") + 1]
    max_used = float(args[args.index("--max-used") + 1])
    size = None
    for l in open(wks):
        if re.search(rf"--part-name\s+{part}\b", l) or re.search(rf"--label\s+{part}\b", l):
            m = re.search(r"--size\s+(\d+)([MG])", l); size = int(m.group(1)) * (1 << 20 if m.group(2) == "M" else 1 << 30)
    if size is None: return res(False, f"partition {part} not found in {wks}")
    import os
    fails = res(os.path.getsize(img) <= size, f"image file {os.path.getsize(img) / 2**20:.0f} MiB, partition {part} {size / 2**20:.0f} MiB")
    h = subprocess.run(["dumpe2fs", "-h", img], capture_output=True, text=True).stdout
    g = lambda k: int(re.search(rf"^{k}:\s+(\d+)", h, re.M).group(1))
    used = (g("Block count") - g("Free blocks")) * g("Block size")
    pct = 100 * used / size
    fails += res(pct <= max_used, f"used {used / 2**20:.0f} MiB is {pct:.0f} percent of the partition (budget {max_used:g} percent)")
    return fails

if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in ("boot", "analyze", "image"):
        print(__doc__); sys.exit(64)
    sys.exit({"boot": boot, "analyze": analyze, "image": image}[sys.argv[1]](sys.argv[2:]))
