# D.8 Key plan sheet

Chapters 10, 12 and 14 describe four families of keys. The sheet lists every key once, with its custodian, the place it lives, its validity and the way it is replaced. A key with a blank rotation cell has no plan, and a key whose validity is shorter than the product life needs one (Design).

| Key | Held by | Lives in | Validity | Replaced by | Loss procedure |
|---|---|---|---|---|---|
| Boot authentication primary key (PPK) |  | Offline module |  | Fixed once its hash is in eFUSE on Zynq UltraScale+; the Versal revocation steps are Not checked (Chapter 10) |  |
| Boot authentication secondary key (SPK) |  | Hardware module |  | New SPK ID under the same PPK |  |
| Update root authority |  | Offline, two custodians |  | Keyring update that holds both authorities |  |
| Update intermediate or signing certificate |  | Hardware module on the signing host |  | Rotation in four steps (Chapter 12) |  |
| Development authority for test units |  | Developer machines |  | Re-issue; never trusted by a production keyring |  |
| Factory authority for unit certificates |  | Hardware module at the station |  | Second authority in the server trust list, then re-issue |  |
| Unit key and certificate | Unit | Unit, mode 0600 |  | Re-provision at a service station |  |
| Server certificate and CA |  | Update server |  | Per the server's own plan |  |

| Question for the whole plan | Answer |
|---|---|
| The longest unit life in years, and the latest end date of any certificate on the unit |  |
| The keyring in the image, and where its digest is recorded |  |
| How a device that skips two releases still reaches a key it trusts |  |
| How a revoked unit is refused by the server, since a device cannot fetch a list while offline |  |
| Who may sign a release, and where the log of signings is kept |  |
| The date of the last rehearsal of a lost signing key (D.7, yearly) |  |

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
