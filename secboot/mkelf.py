#!/usr/bin/env python3
"""Write a minimal AArch64 ELF file with one loadable segment, as a stand-in for a boot firmware ELF file.
Usage: mkelf.py <out.elf> <load address> <payload bytes>"""
import struct, sys

def elf64(path, vaddr, size):
    payload = bytes((i * 7 + 3) & 0xFF for i in range(size))
    ehsize, phsize = 64, 56
    off = ehsize + phsize
    eh = b"\x7fELF" + bytes([2, 1, 1, 0]) + bytes(8) + struct.pack("<HHIQQQIHHHHHH", 2, 183, 1, vaddr, ehsize, 0, 0, ehsize, phsize, 1, 0, 0, 0)
    ph = struct.pack("<IIQQQQQQ", 1, 7, off, vaddr, vaddr, size, size, 0x1000)
    open(path, "wb").write(eh + ph + payload)

if __name__ == "__main__":
    elf64(sys.argv[1], int(sys.argv[2], 0), int(sys.argv[3], 0))
