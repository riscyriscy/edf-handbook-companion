# D.4 Release checklist

This extends the checklist of Chapter 10 with the update items. Each row has an owner and a record, so the list can be audited.

| No | Check | Owner | Record |
|---|---|---|---|
| 1 | Manifest tag and all revisions are recorded and tagged in the project repository | Release | Revision list |
| 2 | Clean build with no network from retained sources succeeds | Release | Build log |
| 3 | Two builds on different hosts give matching images | Release | Hash table |
| 4 | Layer checks and metadata checks pass | CI | CI record |
| 5 | SBOM generated for each image | Release | SPDX files |
| 6 | CVE report reviewed, decisions in CVE_STATUS or patches | Security | Report and notes |
| 7 | Licence review of image content, source archive stored | Legal | Licence manifest |
| 8 | No development features, empty passwords or debug logins in the image | Security | Resolved variable dump |
| 9 | Image size within the slot, with the margin the plan requires | Platform | Size table |
| 10 | Boot test in QEMU passes with stage times recorded | CI | Boot record |
| 11 | Bench tests pass on every board revision that ships | Test | Test record |
| 12 | Update lab passes with all bundle cases | CI | Lab output |
| 13 | Fault injection matrix run for the release candidate | Test | Matrix with dates |
| 14 | Update from the previous release and from the oldest supported release | Test | Update record |
| 15 | Data migration tested on aged data | Application | Migration record |
| 16 | Bundle signed on the signing host by the named person | Update owner | Signing log |
| 17 | Bundle verified on a clean device with the production keyring | Test | Verify output |
| 18 | Rollout plan with canary group and stop limit | Operations | Plan |
| 19 | Known issues and support contacts updated | Support | Release notes |
| 20 | Old release remains buildable | Release | Archive record |
| 21 | Watchdog policy check passes on the root file system (check-watchdog-policy.sh) | Platform | Checker output |
| 22 | Diagnostics policy check passes: journal, core dump limits and ramoops region (check-diag-policy.sh) | Platform | Checker output |
| 23 | Firewall ruleset compiles and the probes match the policy | Security | Probe output |
| 24 | Boot time and image size budgets pass (check-budgets.py) | CI | Budget output |
| 25 | Provisioning verifier passes for every unit of the batch | Production | Verifier log |
| 26 | Signing time setting and certificate end dates match the key plan (T1 to T4) | Update owner | Lab output |

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
