#!/usr/bin/env python3
"""fruimg.py: build, show, check, change and compare a board identity EEPROM image in the layout of the AMD Kria SOM
EEPROM design guide (IPMI FRU: common header, board info area, DC load record, MAC record 0xD2, memory record 0xD3).

This is a lab tool for the handbook. It is not the AMD generator (kria-eeprom-gen) and it writes made up
product data. Use it to see the layout and to test a production station; build the images of a real product with
the tool and the data that the board vendor supplies.

  fruimg.py build  -o FILE --manufacturer M --product P --serial S --part N --rev R --uuid U --mac MAC
  fruimg.py show   FILE
  fruimg.py check  FILE           exit status 0 when the image is valid, 1 when not
  fruimg.py set    FILE -o OUT [--serial S] [--mac MAC] [--rev R] [--product P]
  fruimg.py diff   A B
  fruimg.py uboot  FILE           the environment variables that U-Boot sets from the image
"""
import argparse
import sys
import uuid as uuidlib

SIZE = 256            # bytes written to the file; an erased EEPROM reads 0xFF
BOARD_AT, BOARD_LEN = 0x08, 96
DC_AT, DC_LEN = 0x68, 18
MAC_AT, MAC_LEN = 0x7A, 15
MEM_AT, MEM_LEN = 0x89, 92
IANA = bytes([0xDA, 0x10, 0x00])   # AMD Xilinx, 4314 = 0x10DA, least significant byte first
AREAS = [("common header", 0x00, 8), ("board info area", BOARD_AT, BOARD_LEN), ("DC load record", DC_AT, DC_LEN),
         ("MAC record", MAC_AT, MAC_LEN), ("memory record", MEM_AT, MEM_LEN), ("unused", MEM_AT + MEM_LEN, SIZE - MEM_AT - MEM_LEN)]
MEMORY = [("Memory: ", "QSPI:512Mb"), ("Memory: ", "eMMC:16GB"), ("Memory: ", "PSDDR4:4GB"), ("Memory: ", "PLDDR4:None")]


class BadImage(Exception):
    pass


def zsum(data):
    """The byte that makes the sum of data and itself 0 modulo 256."""
    return (-sum(data)) & 0xFF


def tl(text, ascii_=True):
    raw = text.encode("ascii") if isinstance(text, str) else bytes(text)
    assert len(raw) < 64
    return bytes([(0xC0 if ascii_ else 0x00) | len(raw)]) + raw


def record(rtype, last, payload):
    body = bytes(payload)
    head = bytes([rtype, 0x82 if last else 0x02, len(body), zsum(body)])
    return head + bytes([zsum(head)]) + body


def build(f):
    mac = bytes(int(x, 16) for x in f["mac"].split(":"))
    assert len(mac) == 6
    custom = tl(f["rev"].encode("ascii").ljust(8, b"\0"))[:1] + f["rev"].encode("ascii").ljust(8, b"\0")
    fields = (tl(f["manufacturer"]) + tl(f["product"]) + tl(f["serial"]) + tl(f["part"]) + tl("FRU.1")
              + custom + tl(bytes(8), False) + tl(uuidlib.UUID(f["uuid"]).bytes, False) + b"\xC1")
    area = bytes([1, BOARD_LEN // 8, 0]) + (f.get("minutes", 0)).to_bytes(3, "little") + fields
    area = area.ljust(BOARD_LEN - 1, b"\0")
    area += bytes([zsum(area)])
    dc = record(0x02, False, bytes([0x01]) + (1200).to_bytes(2, "little") + (1080).to_bytes(2, "little")
                + (1320).to_bytes(2, "little") + (120).to_bytes(2, "little") + (0).to_bytes(2, "little") + (3000).to_bytes(2, "little"))
    macrec = record(0xD2, False, IANA + bytes([0x31]) + mac)
    mem = b"".join(n.encode().ljust(8, b" ") + d.encode().ljust(12, b" ") + b"\0" for n, d in MEMORY)
    memrec = record(0xD3, True, IANA + mem)
    assert (len(area), len(dc), len(macrec), len(memrec)) == (BOARD_LEN, DC_LEN, MAC_LEN, MEM_LEN), (len(area), len(dc), len(macrec), len(memrec))
    head = bytes([1, 0, 0, BOARD_AT // 8, 0, DC_AT // 8, 0])
    head += bytes([zsum(head)])
    return (head + area + dc + macrec + memrec).ljust(SIZE, b"\xFF")


def parse_tl(data, pos):
    b = data[pos]
    n = b & 0x3F
    return data[pos + 1:pos + 1 + n], pos + 1 + n, (b >> 6)


def parse(img):
    """Decode an image and verify every checksum and length. Raises BadImage with the first fault."""
    if len(img) < MEM_AT + MEM_LEN:
        raise BadImage("image is %d bytes, shorter than the %d bytes of the layout" % (len(img), MEM_AT + MEM_LEN))
    if img[0] != 1:
        raise BadImage("common header: format version is %d, not 1" % img[0])
    if sum(img[0:8]) & 0xFF:
        raise BadImage("common header: checksum is wrong")
    if (img[3] * 8, img[5] * 8) != (BOARD_AT, DC_AT):
        raise BadImage("common header: area offsets 0x%02X and 0x%02X are not those of the layout" % (img[3] * 8, img[5] * 8))
    area = img[BOARD_AT:BOARD_AT + BOARD_LEN]
    if area[0] != 1 or area[1] * 8 != BOARD_LEN:
        raise BadImage("board info area: version or length is wrong")
    if sum(area) & 0xFF:
        raise BadImage("board info area: checksum is wrong")
    pos = 6
    names = ["manufacturer", "product", "serial", "part", "file_id", "rev", "pcie", "uuid"]
    out = {"minutes": int.from_bytes(area[3:6], "little")}
    for name in names:
        raw, pos, kind = parse_tl(area, pos)
        out[name] = raw.rstrip(b"\0").decode("ascii") if name != "pcie" and name != "uuid" else raw
    if area[pos] != 0xC1:
        raise BadImage("board info area: the end marker 0xC1 is not where the fields end")
    out["uuid"] = str(uuidlib.UUID(bytes=out["uuid"]))
    pos = DC_AT
    for want, at, ln in ((0x02, DC_AT, DC_LEN), (0xD2, MAC_AT, MAC_LEN), (0xD3, MEM_AT, MEM_LEN)):
        rec = img[at:at + ln]
        if rec[0] != want:
            raise BadImage("record at 0x%02X: type 0x%02X, expected 0x%02X" % (at, rec[0], want))
        if sum(rec[0:5]) & 0xFF:
            raise BadImage("record at 0x%02X (type 0x%02X): header checksum is wrong" % (at, want))
        if rec[2] + 5 != ln:
            raise BadImage("record at 0x%02X (type 0x%02X): length byte %d does not match the %d bytes of the record" % (at, want, rec[2], ln - 5))
        if (sum(rec[5:]) + rec[3]) & 0xFF:
            raise BadImage("record at 0x%02X (type 0x%02X): record checksum is wrong" % (at, want))
        if bool(rec[1] & 0x80) != (want == 0xD3):
            raise BadImage("record at 0x%02X (type 0x%02X): the end of list bit is wrong" % (at, want))
    mac = img[MAC_AT + 8:MAC_AT + 9 + 6]
    if img[MAC_AT + 5:MAC_AT + 8] != IANA:
        raise BadImage("MAC record: the manufacturer id is not 0xDA 0x10 0x00")
    out["mac"] = ":".join("%02x" % x for x in img[MAC_AT + 9:MAC_AT + 15])
    return out


def fields_default():
    return {"manufacturer": "EXAMPLE CO", "product": "SOM-X1", "serial": "SN0000001", "part": "PN-100-A", "rev": "A1",
            "uuid": "00000000-0000-4000-8000-000000000001", "mac": "02:00:00:00:00:01", "minutes": 0}


def cmd_build(a):
    f = fields_default()
    for k in ("manufacturer", "product", "serial", "part", "rev", "uuid", "mac"):
        v = getattr(a, k)
        if v is not None:
            f[k] = v
    img = build(f)
    open(a.o, "wb").write(img)
    print("wrote %s: %d bytes, serial %s, mac %s" % (a.o, len(img), f["serial"], f["mac"]))


def cmd_show(a):
    img = open(a.file, "rb").read()
    f = parse(img)
    print("%-14s %s" % ("manufacturer", f["manufacturer"]))
    for k in ("product", "serial", "part", "rev", "uuid", "mac"):
        print("%-14s %s" % (k, f[k]))
    print("areas")
    for name, at, ln in AREAS:
        print("  0x%02X to 0x%02X  %3d bytes  %s" % (at, at + ln - 1, ln, name))


def cmd_check(a):
    try:
        f = parse(open(a.file, "rb").read())
    except BadImage as e:
        print("%s: INVALID: %s" % (a.file, e))
        return 1
    print("%s: valid, serial %s, mac %s" % (a.file, f["serial"], f["mac"]))
    return 0


def cmd_set(a):
    f = parse(open(a.file, "rb").read())
    for k in ("serial", "mac", "rev", "product"):
        v = getattr(a, k)
        if v is not None:
            f[k] = v
    img = build(f)
    open(a.o, "wb").write(img)
    print("wrote %s: serial %s, mac %s, rev %s" % (a.o, f["serial"], f["mac"], f["rev"]))


def area_of(off):
    for name, at, ln in AREAS:
        if at <= off < at + ln:
            return name
    return "outside"


def cmd_diff(a):
    x, y = open(a.a, "rb").read(), open(a.b, "rb").read()
    rows = [i for i in range(min(len(x), len(y))) if x[i] != y[i]]
    for i in rows:
        print("0x%02X  %02X -> %02X  %s" % (i, x[i], y[i], area_of(i)))
    print("%d bytes differ" % len(rows))


def cmd_uboot(a):
    f = parse(open(a.file, "rb").read())
    for k, v in (("board_manufacturer", f["manufacturer"]), ("board_name", f["product"]), ("board_rev", f["rev"]),
                 ("board_serial", f["serial"]), ("board_uuid", f["uuid"]), ("ethaddr", f["mac"])):
        print("%s=%s" % (k, v))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("-o", required=True)
    for k in ("manufacturer", "product", "serial", "part", "rev", "uuid", "mac"):
        b.add_argument("--" + k)
    for name in ("show", "check", "uboot"):
        sub.add_parser(name).add_argument("file")
    s = sub.add_parser("set")
    s.add_argument("file")
    s.add_argument("-o", required=True)
    for k in ("serial", "mac", "rev", "product"):
        s.add_argument("--" + k)
    d = sub.add_parser("diff")
    d.add_argument("a")
    d.add_argument("b")
    a = p.parse_args()
    try:
        r = {"build": cmd_build, "show": cmd_show, "check": cmd_check, "set": cmd_set, "diff": cmd_diff, "uboot": cmd_uboot}[a.cmd](a)
    except BadImage as e:
        print("INVALID: %s" % e)
        return 1
    return r or 0


if __name__ == "__main__":
    sys.exit(main())
