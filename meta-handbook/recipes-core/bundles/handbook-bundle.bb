SUMMARY = "RAUC bundle that carries the handbook root file system"
inherit bundle

RAUC_BUNDLE_FORMAT = "verity"
RAUC_BUNDLE_COMPATIBLE = "handbook-vpk120"
RAUC_BUNDLE_VERSION = "2026.1-r2"
RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_SLOT_rootfs = "handbook-image"
RAUC_SLOT_rootfs[fstype] = "ext4"

RAUC_KEY_FILE = "/etc/handbook-pki/dev.key.pem"
RAUC_CERT_FILE = "/etc/handbook-pki/dev.cert.pem"
