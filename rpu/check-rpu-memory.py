#!/usr/bin/env python3
"""Check the reserved-memory nodes of a compiled device tree: size, alignment, overlap and fit in DDR.

Usage: check-rpu-memory.py <file.dtb> [--align 0x1000] [--cma-align 0x400000]
A region with the 'reusable' property is a CMA pool and must also meet --cma-align.
Needs dtc on the PATH. It reads the DTB through 'dtc -I dtb -O dts', so it works on any host.
Exit status: number of failed checks.
"""
import re, subprocess, sys

def cells(txt):
    return [int(x, 16) for x in re.findall(r"0x[0-9a-fA-F]+", txt)]

def main():
    dtb = sys.argv[1]
    align = int(sys.argv[sys.argv.index("--align") + 1], 0) if "--align" in sys.argv else 0x1000
    dts = subprocess.run(["dtc", "-I", "dtb", "-O", "dts", dtb], capture_output=True, text=True, check=True).stdout
    # memory node: reg = <hi lo hi lo>
    mem = re.search(r"memory@[0-9a-f]+ \{.*?reg = <([^>]*)>", dts, re.S)
    m = cells(mem.group(1))
    ddr = (m[0] << 32 | m[1], (m[0] << 32 | m[1]) + (m[2] << 32 | m[3]))
    rm = re.search(r"reserved-memory \{(.*?)\n\t\};", dts, re.S).group(1)
    cma_align = int(sys.argv[sys.argv.index("--cma-align") + 1], 0) if "--cma-align" in sys.argv else 0x400000
    regions = []
    for name, body in re.findall(r"\n\t\t([\w@,.-]+) \{(.*?)\n\t\t\};", rm, re.S):
        r = re.search(r"reg = <([^>]*)>", body)
        if r:
            c = cells(r.group(1))
            base, size = c[0] << 32 | c[1], c[2] << 32 | c[3]
            regions.append((name, base, size, bool(re.search(r"\breusable;", body))))
    fail = 0
    for name, base, size, reusable in regions:
        probs = []
        if base % align or size % align:
            probs.append("not aligned to 0x%x" % align)
        if reusable and (base % cma_align or size % cma_align):
            probs.append("CMA pool not aligned to 0x%x" % cma_align)
        if base < ddr[0] or base + size > ddr[1]:
            probs.append("outside DDR 0x%x-0x%x" % ddr)
        print("%-4s %-22s 0x%08x 0x%07x %s" % ("FAIL" if probs else "PASS", name, base, size, "; ".join(probs)))
        fail += bool(probs)
    s = sorted(regions, key=lambda r: r[1])
    for a, b in zip(s, s[1:]):
        if a[1] + a[2] > b[1]:
            print("FAIL %s overlaps %s by 0x%x" % (a[0], b[0], a[1] + a[2] - b[1]))
            fail += 1
    print("regions: %d, failures: %d" % (len(regions), fail))
    return fail

if __name__ == "__main__":
    sys.exit(main())
