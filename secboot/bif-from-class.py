#!/usr/bin/env python3
"""Run the BIF writer of meta-xilinx (classes-recipe/bootgen-bif.bbclass) on authentication settings.

Usage: bif-from-class.py <path to bootgen-bif.bbclass> <out.bif>
The function bootgen_bif_create_zynq is cut out of the class and called with a small stand-in for the
BitBake data store, so the BIF text is produced by the same code that xilinx-bootbin uses.
The partition names and flags below are the Zynq UltraScale+ defaults of machine-xilinx-zynqmp.inc,
plus the authentication settings that this book proposes (Design)."""
import re, sys

src = open(sys.argv[1]).read()
m = re.search(r"^def bootgen_bif_create_zynq\(.*?(?=^def |\Z)", src, re.S | re.M)
ns = {}
exec(m.group(0), ns)

class D:
    def __init__(self, flags):
        self.flags = flags
    def getVarFlags(self, name):
        return self.flags.get(name, {})
    def expand(self, s):
        return s

flags = {
    "BIF_COMMON_ATTR": {
        "pskfile": "primary.pem",
        "sskfile": "secondary.pem",
        "auth_params": "ppk_select=0; spk_id=0x00000001",
    },
    "BIF_PARTITION_ATTR": {
        "fsbl": "bootloader, destination_cpu=a53-0, authentication=rsa",
        "arm-trusted-firmware": "destination_cpu=a53-0,exception_level=el-3,trustzone,authentication=rsa",
        "u-boot-xlnx": "destination_cpu=a53-0,exception_level=el-2,authentication=rsa",
    },
}
files = {"fsbl": "fsbl.elf", "arm-trusted-firmware": "atf.elf", "u-boot-xlnx": "u-boot.elf"}
with open(sys.argv[2], "w") as f:
    f.write("the_ROM_image:\n{\n")
    ns["bootgen_bif_create_zynq"](["pskfile", "sskfile", "auth_params"], ["fsbl", "arm-trusted-firmware", "u-boot-xlnx"], files, f, D(flags))
    f.write("}\n")
