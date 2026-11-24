# meta-handbook

Test layer for "The Embedded AMD EDF Handbook". It targets the Poky reference machine (`qemux86-64`) of the sandbox so that metadata behaviour can be checked with BitBake without an EDF workspace. Nothing in it is specific to an AMD device.

## Dependencies

- `openembedded-core` (meta), `bitbake` and `meta-yocto` (meta-poky), at the EDF 26.11 pins (manifest `amd-edf-rel-v26.11`)
- `meta-openembedded` (meta-oe and meta-networking, which supplies nftables for handbook-net), at the EDF 26.11 pin
- `meta-rauc`, branch wrynose (only the bundle recipe needs it)

## Contents

| Path | Holds |
|---|---|
| `conf/layer.conf` | layer configuration |
| `recipes-apps/edf-hello` | script and systemd unit installed by a recipe |
| `recipes-apps/edf-app` | CMake application |
| `recipes-core/base-files` | bbappend that mounts the data partition and writes the release identity |
| `recipes-core/busybox` | bbappend with a configuration fragment |
| `recipes-core/images` | `handbook-image` |
| `recipes-core/packagegroups` | `packagegroup-handbook-tools` |
| `recipes-core/bundles` | RAUC bundle recipe |
| `recipes-core/handbook-watchdog` | systemd watchdog drop-in |
| `recipes-core/handbook-diag` | journald, coredump and pstore drop-ins |
| `recipes-core/handbook-net` | network files and firewall |
| `recipes-kernel/hello-mod` | out-of-tree kernel module |
| `recipes-kernel/linux` | kernel configuration fragments `pstore.cfg`, `rt.cfg` and `debugfs.cfg` |
| `recipes-rpu/handbook-rpu` | start and stop script, systemd unit and a fixture ELF header |
| `recipes-update/handbook-fwenv` | `fw_env.config` |
| `recipes-update/handbook-health` | health check script and unit |
| `recipes-update/handbook-migrate` | data migration script and unit |
| `recipes-update/rauc` | RAUC `system.conf` and the test certificate |
| `files/wic/handbook-ab.wks` | A/B partition table |
| `SECURITY.md` | where to report a fault |

## Maintainers and patches

Maintainer: the author of the book, at handbook-maintainers@example.com. The address is a placeholder from the reserved example.com domain, so replace it with the address of your own team. This layer carries no patches. Send a patch to the maintainer as an email or a pull request.
