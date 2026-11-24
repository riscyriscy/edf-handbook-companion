# D.9 Station work instruction

The instruction belongs next to the station, and its version is part of the ledger record. The stages S1 to S9 are those of Step 11 in Chapter 14, in the same order: eFUSE programming (S8) cannot be undone, so every check that can run without it comes first. provision-unit.sh covers S3 to S5 and writes the ledger line that S7 checks, and verify-unit.sh covers S6 except the EEPROM comparison, which the check of Step 12 in Chapter 14 covers. The status values are the exit statuses of provision-unit.sh (Run).

| Stage | Action | Pass condition | On failure |
|---|---|---|---|
| S1 | Flash the release image and boot firmware; write the board identity EEPROM (Step 12 of Chapter 14); boot once | Console reaches the login prompt; the EEPROM reads back equal to the image | Reflash and rewrite once; second failure goes to the scrap bin |
| S2 | Run the board self-test | Every line reports pass | Record the failing line; decide per the repair table below |
| S3 to S5 | Run provision-unit.sh <unit-dir> <serial> <factory-ca-dir> <ledger>. It generates the key pair on the unit with the serial as subject, signs the request and installs the certificates | Exit status 0; key file mode is 0600 | Status 2: serial format wrong. Status 3: serial already in the ledger. Status 4: request names another serial. Stop; do not retry with a new serial without a supervisor |
| S6 | Run verify-unit.sh on the unit directory | Exit status 0; chain, subject, key match, key mode and keyring digest agree; the serial and MAC from the EEPROM equal the assigned ones | Do not program eFUSE. Reflash from S1 |
| S7 | Check the ledger line | One line: serial, certificate fingerprint, UTC timestamp | Remove nothing by hand; call the ledger owner |
| S8 | Program the eFUSE and read it back | Read-back equals the release record | Mark the unit as partly fused; see the repair table |
| S9 | Boot with secure boot enforced and rerun the self-test | Every line reports pass | Mark the unit as fused and failed; see the repair table |
| After S9 | Print the label from the ledger line | Serial on the label equals the ledger serial | Reprint |

| Ledger field | Source | Rule |
|---|---|---|
| Serial | Station assignment | Two letters and six digits; unique across the product |
| Certificate fingerprint | Output of provision-unit.sh | SHA-256 of the signed certificate, hex without colons |
| Timestamp | Station clock, UTC | Station clock is checked against a reference at shift start |
| Release | Release record identifier | Image, keyring digest and boot firmware hash |
| Station and operator | Station | Identifier, not a name |
| Instruction version | This sheet | Version of this sheet at the time of the run |
| Result | Stages S8 and S9 | Pass, scrap, or fused and failed |

Decide before the first unit what each outcome of stages S8 and S9 means: whether a unit that is fused but fails the final self-test can be repaired, and who decides. Write the answer in the repair table of the instruction, because an operator at the station cannot reason from the fuse map.

| Outcome | Decision (fill in) | Decided by |
|---|---|---|
| Self-test fails at S2, no fuse written |  |  |
| S3 to S6 fail, no fuse written |  |  |
| S8 fails with fuses partly written |  |  |
| S9 fails with all fuses written |  |  |
| Serial already in the ledger |  |  |

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
