SUMMARY = "Persistent journal, core dump limits and pstore archiving for the product image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = " \
    file://10-handbook-journald.conf \
    file://10-handbook-coredump.conf \
    file://10-handbook-pstore.conf \
"
S = "${UNPACKDIR}"

inherit allarch
RDEPENDS:${PN} += "systemd"

do_install() {
    install -d ${D}${sysconfdir}/systemd/journald.conf.d
    install -d ${D}${sysconfdir}/systemd/coredump.conf.d
    install -d ${D}${sysconfdir}/systemd/pstore.conf.d
    install -m 0644 ${UNPACKDIR}/10-handbook-journald.conf ${D}${sysconfdir}/systemd/journald.conf.d/
    install -m 0644 ${UNPACKDIR}/10-handbook-coredump.conf ${D}${sysconfdir}/systemd/coredump.conf.d/
    install -m 0644 ${UNPACKDIR}/10-handbook-pstore.conf ${D}${sysconfdir}/systemd/pstore.conf.d/
}
FILES:${PN} = "${sysconfdir}/systemd/journald.conf.d ${sysconfdir}/systemd/coredump.conf.d ${sysconfdir}/systemd/pstore.conf.d"
