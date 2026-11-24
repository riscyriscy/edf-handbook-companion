SUMMARY = "Out-of-tree kernel module example"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit module

SRC_URI = "file://Makefile \
           file://hello_mod.c"
S = "${UNPACKDIR}"

RPROVIDES:${PN} += "kernel-module-hello-mod"
