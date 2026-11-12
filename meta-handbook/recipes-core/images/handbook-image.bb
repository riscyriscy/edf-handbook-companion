SUMMARY = "Handbook example image"
LICENSE = "MIT"

require recipes-core/images/core-image-minimal.bb

IMAGE_FEATURES += "ssh-server-openssh"
IMAGE_INSTALL:append = " edf-hello packagegroup-handbook-tools"
IMAGE_FSTYPES += "wic"
