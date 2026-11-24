# D.5 Decision records

A short decision record keeps a choice from being reopened without new facts. The form below has six fields. Three worked records follow, using the facts of this book.

| Field | Content |
|---|---|
| Title | Short name of the decision |
| Status | Proposed, accepted, replaced (with the record that replaced it) |
| Context | The facts that force the decision, with their sources |
| Decision | What was chosen, in one paragraph |
| Consequences | What gets easier, what gets harder, and what becomes a task |
| Review date | The date or event that triggers a second look |

## Record 1: bootloader integration for RAUC

| Field | Content |
|---|---|
| Context | EDF boots through U-Boot, then systemd-boot on the default path. RAUC needs a backend that chooses the slot. The U-Boot variable backend is documented and the lab tested the interface with a custom backend (Chapter 12). |
| Decision | Option A: U-Boot variables and a boot script, with RAUC's uboot backend and a fw_env.config for the flash. |
| Consequences | The script path of EDF replaces the UEFI path for the root slot choice. The U-Boot environment location must be confirmed for the product flash. A firmware bank switch may change the environment copy, which needs a test. |
| Review date | After the first board test of fault P1 to P3, or when EDF changes its default boot path. |

## Record 2: bundle format

| Field | Content |
|---|---|
| Context | Verity bundles verify blocks as they are read and stream over HTTP. They need device-mapper and dm-verity in the kernel. A QEMU guest with another kernel installed one (Chapter 12). xilinx_defconfig of the pinned linux-xlnx kernel does not set them (Source). See Chapter 12. |
| Decision | Verity only, with bundle-formats=-plain, conditional on the kernel options. |
| Consequences | A kernel fragment adds device-mapper and dm-verity. The CI lab builds both formats. If the EDF kernel cannot carry the options, the decision is replaced. |
| Review date | After the first kernel build with the fragment. |

## Record 3: boot media

| Field | Content |
|---|---|
| Context | EDF's flash images (edf-ospi, edf-qspi) carry the image selector, A/B boot images, recovery and update metadata. SD boot needs boot.bin copied into the first partition by hand. Boot firmware updates in the field need the flash path (Chapter 11). |
| Decision | SD for bring-up, OSPI for production, with the flash layout checked against the product's flash. |
| Consequences | The edf-env.cfg offsets may need a bbappend. The capsule flow needs PRODUCT_GUID, PRODUCT_NAME and PRODUCT_URL in the machine. Two boot paths need two test plans. |
| Review date | When the flash part and its size are final. |

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
