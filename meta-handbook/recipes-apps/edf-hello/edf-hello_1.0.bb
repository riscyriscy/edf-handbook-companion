SUMMARY = "Install a shell script and a systemd unit"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://edf-hello.sh \
           file://edf-hello.service"
S = "${UNPACKDIR}"

inherit systemd
SYSTEMD_SERVICE:${PN} = "edf-hello.service"

do_install() {
    install -Dm 0755 ${S}/edf-hello.sh ${D}${bindir}/edf-hello
    install -Dm 0644 ${S}/edf-hello.service ${D}${systemd_system_unitdir}/edf-hello.service
}
