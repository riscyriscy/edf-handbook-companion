# D.6 A repository layout

The layout below keeps AMD's layers, the product's layers and the generated hardware files apart. It is a convention, not an EDF requirement (Design).

**Repository tree (Design)**

```
product/
  manifest/                 product.xml: repo manifest that pins EDF and the product layers
  layers/
    meta-product-bsp/       generated machine, device tree include, U-Boot and kernel fragments
    meta-product-distro/    distribution policy, image feature and licence policy
    meta-product-apps/      application recipes, services, packagegroups
    meta-product-update/    RAUC configuration, health check, migration, bundle recipe
  hw/
    xsa/                    delivered XSA files, never edited
    handoff.txt             hash and tool versions of the last delivery
  scripts/
    setup-workspace.sh      fetch the manifest, add layers, share caches
    regen-hw.sh             XSA to committed machine files
    check-metadata.sh       metadata checks for CI
  ci/                       pipeline definition, console checker, lab scripts
  docs/                     decision records, handoff agreement, release checklist
  keys/                     public certificates only; the signing key is never here
```

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
