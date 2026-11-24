# D.1 Update requirements sheet

Fill this before choosing a mechanism. The third column shows the default that this book assumes, so the sheet also shows where the product departs from it.

| Requirement | Book default | Product value |
|---|---|---|
| Units updated in the field | Root file system and kernel together; boot firmware separately |  |
| Boot firmware update allowed in the field | Yes, through the EDF capsule flow, with a recovery path |  |
| Programmable logic image updated alone | Yes if segmented, as a firmware bundle |  |
| Maximum interrupted updates before intervention | Any number; the old slot always boots |  |
| Power loss at any instant must leave a bootable device | Yes |  |
| Rollback after a failed boot | Automatic after 3 attempts |  |
| Rollback after a failed health check | Automatic through mark-good gating and a reboot on failure |  |
| Hardware watchdog timeout | Set in seconds; tested on the board |  |
| Downgrade allowed | No; version counters rise |  |
| Bundle signature required | Yes; code signing purpose; verity format |  |
| Signing key custody | Offline root, intermediate in a hardware module |  |
| Maximum bundle size | Measured image plus margin |  |
| Maximum update download time | Not specified |  |
| Update window | Device idle or user consent |  |
| Data migration needed | On first boot of new release, idempotent |  |
| Delivery path | Server managed or offline media |  |
| Lifetime of the product in the field | Ten years, which exceeds the Wrynose support date |  |
| Support plan after Wrynose ends in April 2030 | Move to a newer EDF release |  |

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
