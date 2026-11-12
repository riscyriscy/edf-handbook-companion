Chapter 6. A stand-in for linux-xlnx that sets KCONF_AUDIT_LEVEL="0", and a bbappend that sets "1".
To repeat: put layer.conf under conf/, the two recipe files under recipes-test/fakek/, add the directory as a layer
to a Poky 5.0 build (bitbake-layers add-layer), then run
  bitbake-getvar -r fakek --value KCONF_AUDIT_LEVEL
with and without the bbappend. The output is in listings/kconf_audit.out.txt of the book source.
