SUMMARY = "Real time core firmware and its start script for remoteproc"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

# handbook-rpu0.elf in files/ is a test fixture. A product replaces it with the artifact of its RPU build,
# pinned by checksum in SRC_URI.
SRC_URI = "file://handbook-rpu0.elf file://handbook-rpu file://handbook-rpu.service"
S = "${WORKDIR}"

inherit systemd allarch
SYSTEMD_SERVICE:${PN} = "handbook-rpu.service"

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware ${D}${bindir} ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/handbook-rpu0.elf ${D}${nonarch_base_libdir}/firmware/
    install -m 0755 ${WORKDIR}/handbook-rpu ${D}${bindir}/
    install -m 0644 ${WORKDIR}/handbook-rpu.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${nonarch_base_libdir}/firmware"
