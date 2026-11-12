# Mount the shared data partition, and keep the release identity where the health check and migration read it.
do_install:append() {
    echo "PARTLABEL=data  /data  ext4  defaults,noatime  0  2" >> ${D}${sysconfdir}/fstab
    install -d ${D}/data
    echo "${DISTRO_VERSION}" > ${D}${sysconfdir}/handbook-release
}
FILES:${PN} += "/data ${sysconfdir}/handbook-release"
