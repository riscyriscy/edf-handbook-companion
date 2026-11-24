# D.12 Budget table

One row per release, kept in version control. check-budgets.py supplies the stage times and the image fill (Chapter 15). A release that exceeds a limit needs a decision record (D.5) before it ships. The limits in the second row are placeholders to replace with measured values from the board.

| Release | Kernel time (s) | User space time (s) | Image fill (percent) | Bundle size (MiB) | Download time (min) |
|---|---|---|---|---|---|
| Limit |  |  | 75 in the chapter's example |  |  |
| Previous release |  |  |  |  |  |
| This release |  |  |  |  |  |
| Change |  |  |  |  |  |

| Stage | Limit | Source of the time |
|---|---|---|
| Boot firmware to kernel start |  | Console checker |
| Kernel start to root file system mounted |  | Console checker |
| Root file system to login or application ready |  | Console checker |
| Application ready to health check passed |  | Console checker |
| Update install, from download start to reboot |  | Update lab |
| First boot after update, including migration |  | Update lab |

Compute the image fill as used bytes over the slot size, where used bytes include the file system's own overhead: an empty ext4 file system of 1536 MiB already counts 61 MiB as used in the chapter's run. Compute the download time as the bundle size in bits over the link rate: 1 GiB over 2 Mbit/s is 72 minutes.

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
