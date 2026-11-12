SUMMARY = "Static addressing, a management VLAN and a host firewall for the product image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = " \
    file://10-eth0.network \
    file://10-vlan20.netdev \
    file://20-vlan20.network \
    file://handbook-firewall.nft \
    file://handbook-firewall.service \
"
S = "${WORKDIR}"

inherit allarch systemd
RDEPENDS:${PN} += "systemd nftables"
# CONFIG_VLAN_8021Q must be built in or a module. RRECOMMENDS does not fail the image when the driver is built in.
RRECOMMENDS:${PN} += "kernel-module-8021q"

SYSTEMD_SERVICE:${PN} = "handbook-firewall.service"

do_install() {
    install -d ${D}${sysconfdir}/systemd/network
    install -m 0644 ${WORKDIR}/10-eth0.network ${WORKDIR}/10-vlan20.netdev ${WORKDIR}/20-vlan20.network ${D}${sysconfdir}/systemd/network/
    install -m 0600 ${WORKDIR}/handbook-firewall.nft ${D}${sysconfdir}/handbook-firewall.nft
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/handbook-firewall.service ${D}${systemd_system_unitdir}/
}
FILES:${PN} = "${sysconfdir}/systemd/network ${sysconfdir}/handbook-firewall.nft ${systemd_system_unitdir}/handbook-firewall.service"
