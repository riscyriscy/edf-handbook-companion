SUMMARY = "First boot data migration for a new release"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = "file://handbook-migrate file://handbook-migrate.service"
S = "${WORKDIR}"

inherit systemd allarch
SYSTEMD_SERVICE:${PN} = "handbook-migrate.service"

do_install() {
    install -d ${D}${bindir} ${D}${systemd_system_unitdir} ${D}${libdir}/handbook/migrate.d
    install -m 0755 ${WORKDIR}/handbook-migrate ${D}${bindir}/
    install -m 0644 ${WORKDIR}/handbook-migrate.service ${D}${systemd_system_unitdir}/
}
FILES:${PN} += "${libdir}/handbook"
