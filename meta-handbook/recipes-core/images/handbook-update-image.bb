SUMMARY = "Handbook image with the A/B update pieces"
require handbook-image.bb

inherit features_check
REQUIRED_DISTRO_FEATURES = "systemd rauc"

IMAGE_INSTALL:append = " rauc rauc-conf handbook-health handbook-migrate handbook-fwenv"
