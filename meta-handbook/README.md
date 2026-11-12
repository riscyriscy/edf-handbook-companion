meta-handbook
=============

Test layer for "The Embedded AMD EDF Handbook". It targets the Poky reference machine
(qemux86-64) of the sandbox so that metadata behaviour can be checked with BitBake
without an EDF workspace. Nothing in it is specific to an AMD device.

Dependencies
------------

* poky (meta), branch scarthgap, tag yocto-5.0.15
* meta-rauc, branch scarthgap (only the bundle recipe needs it)

Contents
--------

* recipes-apps/edf-hello      script and systemd unit installed by a recipe
* recipes-apps/edf-app        CMake application
* recipes-core/busybox        bbappend with a configuration fragment
* recipes-core/images         handbook-image
* recipes-core/packagegroups  packagegroup-handbook-tools
* recipes-core/bundles        RAUC bundle recipe
* recipes-kernel/hello-mod    out-of-tree kernel module
* recipes-kernel/linux        kernel configuration fragment

Patches and contact
-------------------

This layer carries no patches. Send comments to the book's author.
