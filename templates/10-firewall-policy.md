# D.10 Firewall policy sheet

The sheet states the policy that handbook-firewall.nft implements (Chapter 7). Fill it before writing the ruleset, and compare the ruleset with it in review. The default column shows what the chapter's example does.

| Item | Chapter 7 example | Product value |
|---|---|---|
| Default input policy | Drop |  |
| Default forward policy | Drop; the device does not route |  |
| Interfaces and their role | Management and control networks on separate interfaces |  |
| Management port 22 (SSH) | Interface vlan20 only; 6 new connections a minute, burst of 5 |  |
| Control port 502 (Modbus TCP) | Interface eth0 and source 192.0.2.0/24 only |  |
| Port 443 (HTTPS) | Interfaces eth0 and vlan20 |  |
| ICMP | Echo request at 10 a second; IPv6 neighbour discovery accepted |  |
| Invalid, loopback and established traffic | Invalid dropped; loopback and established accepted |  |
| Other ports and the output chain | Input dropped, a client sees a timeout; output accepted |  |
| Load order | Before network-pre.target, so no interface is open without rules |  |
| How the ruleset replaces itself | delete table inet handbook, never flush ruleset |  |
| Owner of each opened port |  |  |
| Review date for each opened port |  |  |
| Test that proves each row | Namespace test in run-net-check.sh |  |

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
