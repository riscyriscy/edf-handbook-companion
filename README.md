# The Embedded AMD EDF Handbook: companion files

This repository holds the files that the book shows or refers to. Everything was written and run in a sandbox without AMD hardware: BitBake 2.18.0 (OpenEmbedded-Core 8830751, Yocto 6.0 Wrynose, distribution version 6.0.3), RAUC 1.11.3 and dtc 1.7.0 on Ubuntu 24.04. The files follow EDF 26.11. The first printing followed EDF 26.06.1 on Scarthgap, and the old files are in the history of this repository. One run still used the wic parser of Poky 5.0.15, because the Wrynose wic recipe could not be fetched in the sandbox (Chapter 18).

## Contents

### meta-handbook/

Test layer for the Poky reference machine (`qemux86-64`). It depends on `openembedded-core` (meta), `meta-poky`, `meta-openembedded` (meta-oe, meta-python and meta-networking) and `meta-rauc`, wrynose branch. It holds the recipes for the examples of Chapters 2, 6, 7, 8, 12, 18 and 19:

- image, packagegroup, application, kernel module
- RAUC configuration, health check, data migration, `fw_env.config`, A/B partition table
- `recipes-rpu/handbook-rpu`: start and stop script, systemd unit and a fixture ELF header
- `recipes-core/handbook-watchdog`: a systemd watchdog drop-in
- `recipes-core/handbook-diag`: journald, coredump and pstore drop-ins
- `recipes-core/handbook-net`: network files and firewall
- `recipes-kernel/linux`: `pstore.cfg` and `rt.cfg` fragments

### rauc-lab/

Offline RAUC lab (Chapters 12, 15, 16 and 18, and Appendix E). Run as root. Keys are generated into `work/` and are for testing only.

| File | Purpose |
|---|---|
| `run-lab.sh` | Builds a test PKI and bundles, runs verification, tamper, clock and install cases |
| `run-errors.sh` | Four install failures (run after `run-lab.sh`) |
| `run-keys.sh` | Key rotation and re-signing (run after `run-lab.sh`) |
| `run-signtime.sh` | Signing time and device clock matrix (Chapter 12) |
| `run-plain-tamper.sh` | One payload byte changed in a plain and in a verity bundle (Chapter 12) |
| `run-delta.sh` | Adaptive delta bundle sizes for ext4 and squashfs images (Chapter 12) |
| `backend.sh` | Test double for a bootloader backend |
| `out/` | Transcripts produced by the scripts, as quoted in the book |

### templates/

The templates for a product team of Appendix D, one Markdown file each: update requirements, handoff agreement, fault injection matrix, release checklist, decision records, repository layout, maintenance calendar, key plan, station work instruction, firewall policy, diagnostics policy and budget table. `templates/README.md` lists them with their chapters. Designs, not AMD material, and not tested on a product.

### verity-vm/

Chapter 12. QEMU guest labs (Ubuntu 6.8 kernel, no KVM, no root).

| File | Purpose |
|---|---|
| `prepare-kernel.sh` | Downloads the kernel image and three modules into `kernel/` |
| `run-verity-root.sh` | dm-verity root from an initramfs in six cases |
| `run-rauc-verity.sh` | RAUC verity and adaptive bundles in virtio disk slots, damaged bundles, HTTP streaming, and HTTPS streaming with a client certificate (Chapter 13) |
| `mkinitramfs.sh`, `init-verity-root`, `root-init`, `init-rauc-lab`, `tests-rauc.sh`, `range-server.py` | Support files of the labs |
| `out/` | Transcripts quoted in the book |

### Other directories

| Directory | Chapter | Contents |
|---|---|---|
| `rpu/` | 19 | Reserved memory fragments (good, overlapping, outside DDR), stub top level device trees, `check-rpu-memory.py` and `run-rpu-check.sh` (needs `dtc` and `python3`), `out/` with the captured result |
| `dma/` | 6 | A CMA pool and `u-dma-buf` node fragment with two faulty copies (misaligned, overlapping the R5F region), stub top level trees and `run-dma-check.sh`, which uses `../rpu/check-rpu-memory.py`; `handbook_dmacopy.c`, a dmaengine client, and `qemu/` with `build.sh` (linux-xlnx at the pinned revision with the client built in, needs `gcc-aarch64-linux-gnu`), `runq.sh` (boots it on the QEMU machine `xlnx-zcu102` with two GDMA channels and dmatest), the device tree, `init.c` and the captured output |
| `ci/` | 15 | `check-watchdog-policy.sh` (checks the effective watchdog settings and the health unit of a root file system; needs `systemd-analyze`); `test_rpu_start.sh` and `fake_remoteproc.py` (nine cases for `handbook-rpu` against a scripted stand-in for the remoteproc sysfs files; needs `python3` and `sh`); `check-diag-policy.sh` (checks journald, coredump and pstore settings of a root file system); `check-budgets.py` and `run-budgets.sh` (boot time and image size gates; `fixtures/` holds `systemd-analyze` outputs); `check-metadata.sh` (metadata checks for CI); `console_check.py` and `fake_target.py` (boot stage checker and a scripted stand-in for a board console; needs `pexpect`) |
| `secboot/` | 10 | Secure boot walk-through with `bootgen`: BIF files for authentication and key sources, `bif-from-class.py`, `mkelf.py` (stand-in ELF files) and `run-secboot.sh`. Needs `bootgen` |
| `debug/` | 8 | `crash.c` and `run-debug.sh`: gdbserver with split debug symbols, x86 and aarch64 (QEMU user mode). Needs `gdb`, `gdbserver`, `gdb-multiarch` and `qemu-user` |
| `diag/` | 8 | `ramoops.dtsi` (reserved memory node for pstore), stub top level tree and `run-diag-check.sh` (needs `dtc`) |
| `net/` | 7 | systemd-networkd files, the nftables ruleset and unit, and `run-net-check.sh`, which tests the rules in network namespaces (needs root, `iproute2`, `nftables`) |
| `rt/` | 6 | `check-cyclictest.py` (parses cyclictest output against a limit), `check-rt-config.sh` (checks a kernel configuration for PREEMPT_RT options), fixtures and `run-rt-check.sh` |
| `storage/` | 7, 10 | `writer.py`, `verify.py` and `run-powercut.sh` (simulated power cuts on a loop device; the cut comes 0.2 to 0.6 s after the start, or at `CUT_AFTER` seconds), `run-fsck.sh` (e2fsck exit statuses), `run-overlay.sh` (read only root with overlay) and `run-luks.sh` (LUKS2 header and key slot checks on an image file for the encrypted data partition of Chapter 10; needs `cryptsetup`, no device mapper) |
| `provision/` | 14 | `provision-unit.sh`, `verify-unit.sh` and `run-provision.sh`: key on the unit, CSR signed by a factory CA, serial ledger and end of line verifier. Test keys only |
| `board-id/` | 14 | `fruimg.py` builds, shows, checks, changes and compares a board identity EEPROM image in the layout of the AMD Kria SOM EEPROM design guide (made up product data), and `run-board-id.sh` runs it with `dd` on a file and `ipmi-fru` as a second decoder. Not the AMD generator |
| `hil/` | 15 | labgrid environment files, `test_boot.py` and `run-labgrid.sh` against a scripted console (needs labgrid in a virtual environment) |
| `kconf/` | 6 | A stand-in recipe with `KCONF_AUDIT_LEVEL="0"`, a bbappend that sets `"1"`, and `layer.conf` |

## Status

The book tags every statement as Run, Docs, Source, Course or Design. The layer was parsed, not built. No image booted. The scripts in this repository are the ones that produced the outputs in the book. Check every file against your own versions before using it in a product. Never copy the test keys.

## Licence

MIT. See `LICENSE`. The test certificate in `meta-handbook/recipes-update/rauc/files/ca.cert.pem` and every key that the scripts generate are for testing only. AMD, Xilinx, Yocto Project and RAUC names belong to their owners. This repository holds no AMD source code, no AMD course material and no vendor binaries.
