SUMMARY = "CMake application that reads a UIO device"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://CMakeLists.txt \
           file://main.c"
S = "${UNPACKDIR}"

inherit cmake

EXTRA_OECMAKE += "-DAPP_VERSION=${PV}"
