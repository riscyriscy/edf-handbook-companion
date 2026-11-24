# D.11 Diagnostics policy sheet

The sheet fixes what the device keeps for a failure analysis and how much flash and DDR that costs. The values in the middle column are those of Chapter 8. check-diag-policy.sh reads a root file system and fails if the journal is not persistent, /var/log is a link, a core dump limit is unset or the pstore archive does not unlink its files (Run).

| Item | Chapter 8 example | Product value |
|---|---|---|
| Where /var/log lives | Flash partition; VOLATILE_LOG_DIR = "no" |  |
| Journal size cap | SystemMaxUse=32M, SystemMaxFileSize=4M |  |
| Journal retention | MaxRetentionSec=14day |  |
| Rate limit | 2000 messages per 30 seconds |  |
| Share of the flash write budget for logs |  |  |
| Core dumps | Enabled; 64 MiB per process |  |
| Core dump total cap and free space kept |  |  |
| Debug symbol archive | Per build identifier on the build server |  |
| pstore region | 1 MiB of DDR, reserved, address checked against the memory map |  |
| pstore collection | systemd-pstore, files moved to /var/lib/systemd/pstore |  |
| DDR retention across the reset path | Not known until tested on the board |  |
| Log forwarding | systemd-journal-upload if the product has a network |  |
| Privacy limits on what logs may contain |  |  |
| Who reads the logs, and how a unit in the field delivers them |  |  |

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
