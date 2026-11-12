# Project system.conf and keyring for RAUC. FILESEXTRAPATHS makes the files below win over meta-rauc's examples.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
RAUC_KEYRING_FILE = "ca.cert.pem"
