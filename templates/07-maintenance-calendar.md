# D.7 A maintenance calendar

| Interval | Work | Output |
|---|---|---|
| Every commit | Metadata checks, layer checks, QEMU boot, update lab | CI result |
| Daily | Clean build, CVE scan of the release branch | Build and CVE records |
| Weekly | CVE review meeting; decisions in CVE_STATUS or patches | Decision log |
| Monthly | Rebuild of the release branch with updated recipes; buildhistory diff | Diff report |
| Quarterly | Signed bundle for the field; fault matrix rerun | Release record |
| Half yearly | Read the EDF release notes; decide whether to move | Decision record |
| Yearly | Key review: validity, custody, rotation plan; rehearsal of a recovery from a lost signing key | Key review record |

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
