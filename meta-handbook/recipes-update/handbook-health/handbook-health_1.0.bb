SUMMARY = "Health check that gates RAUC's mark-good step"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = "file://handbook-health-check file://handbook-health.service"
S = "${UNPACKDIR}"

inherit systemd allarch
SYSTEMD_SERVICE:${PN} = "handbook-health.service"
RDEPENDS:${PN} += "systemd"

do_install() {
    install -d ${D}${bindir} ${D}${systemd_system_unitdir}
    install -m 0755 ${UNPACKDIR}/handbook-health-check ${D}${bindir}/
    install -m 0644 ${UNPACKDIR}/handbook-health.service ${D}${systemd_system_unitdir}/
}
