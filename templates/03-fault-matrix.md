# D.3 Fault injection matrix

Chapter 12 lists the fault classes. The matrix assigns an identifier to each case, so a test report can refer to it. Mark each row with the date, the build and the result. The first column carries a letter for the class: B for bundle, S for storage, P for power, C for clock, K for key, A for application, R for rollback, W for watchdog, T for signing time, D for delta bundle.

| ID | Fault | How to inject | Expected result |
|---|---|---|---|
| B1 | Bundle signed by an unknown CA | Sign with a second test CA | Rejected before any write |
| B2 | Signature bytes damaged | Flip a byte near the end | Rejected: invalid signature data |
| B3 | Payload damaged, verity bundle | Flip a byte in the payload | rauc info passes; extract fails with bundle payload is corrupted; an install stops at the bad block with an input/output error and the slot stays marked bad |
| B4 | Wrong compatible string | Build for another board name | Rejected: compatible mismatch |
| B5 | Unknown slot class in manifest | Add an image the device has no slot for | Rejected: no target slot |
| B6 | Plain bundle where verity is required | Build in plain format | Rejected by the format policy |
| B7 | Payload damaged, plain bundle | Flip a byte in the payload | Rejected at verification: signature verification failed |
| S1 | Download interrupted | Cut the link at 50 percent | Nothing written; retry works |
| S2 | Inactive slot too small | Use a larger image | Install refused before write |
| S3 | Data partition full | Fill it, then update | Update works; application fails safely |
| P1 | Power cut during slot write | Cut power at 10, 50 and 90 percent | Old slot boots; new write restarts |
| P2 | Power cut after write, before bootloader switch | Cut at that point | Old slot boots |
| P3 | Power cut during first boot of new slot | Cut during migration | Boot counter lets the new slot retry, then falls back |
| P4 | Power cut during boot firmware update | Cut during capsule apply | Recovery or the other bank boots |
| C1 | Device clock before the certificate start | Set 2020 | Rejected: not yet valid |
| C2 | Device clock after the certificate end | Set 2028 | Rejected: expired |
| C3 | No trusted time source at boot | Disconnect network and RTC | Defined behaviour, documented |
| K1 | Keyring holds the new CA only | Install an old bundle | Rejected; supports the rotation plan |
| K2 | Keyring update bundle | Ship both CAs in a normal bundle | Both generations accepted afterwards |
| A1 | Application crashes on start | Ship a build with a deliberate crash | Health check fails; rollback |
| A2 | Application hangs | Ship a build that never reports ready | Health check timeout; rollback |
| R1 | Rollback after three failed boots | Corrupt the new kernel | Old slot active; state recorded |
| R2 | Downgrade attempt | Install an older version | Refused by the counter or policy |
| R3 | Update after a rollback | Install the fixed version | Works; slot states consistent |
| W1 | Kernel stops during boot | Test module that loops forever in its init function, with panic=0 | Resets only if the bootloader or the kernel started the watchdog; otherwise the device stays stopped and the test records that gap |
| W2 | A service stops reporting | Service with WatchdogSec= that stops calling sd_notify | systemd restarts the service by its Restart= policy; if the restarts fail, the health check fails and the slot falls back |
| T1 | Clock after the signer certificate ended, signing time not used | Set 2028 for a bundle signed in 2026 | Rejected: certificate has expired |
| T2 | Same bundle with use-bundle-signing-time=true | Same clock as T1 | Accepted |
| T3 | Bundle built after the signer certificate ended | Build with the clock at 2028 | Rejected even with the signing time setting |
| T4 | Bundle built with a signing host clock set back | Build with the clock at a date inside the validity | Accepted with the signing time setting, so the signing host clock needs protection |
| D1 | Adaptive image size not a multiple of 4096 bytes | Build with an image of 1000001 bytes | Bundle build fails; the build check names the size |
| D2 | Slot corrupt in the block the index points to | Damage that block in the old slot, then install | Hash check rejects the block; install finishes with a correct slot or fails cleanly |

B1 to B3, B5, B7, C1, C2, T1 to T4 and D1 ran in the book's RAUC lab with the messages shown in Chapters 12 and 16. B3 on the install side and D2 ran in the QEMU guest of Chapter 12. B4 also ran. The remaining rows need the product's bootloader integration, and several need a board with controlled power.

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
