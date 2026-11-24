# D.2 Hardware and software handoff agreement

Chapter 4 explains each item. The agreement is a signed page, and the XSA hash for each delivery is added to it.

| Item | Agreed value | Owner |
|---|---|---|
| Vivado version |  | Hardware |
| Top level is a block design (no RTL top, no Block Design Containers) |  | Hardware |
| Flat or segmented configuration |  | Both |
| Processor domains and which one runs Linux |  | Both |
| MicroBlaze instances and who owns their software |  | Hardware |
| Address map document and revision |  | Hardware |
| Interrupt and clock naming rule |  | Both |
| Device tree names for each programmable logic block |  | Software |
| The blocks that bind to UIO and the blocks that need a driver |  | Software |
| Boot media and boot mode pin settings |  | Both |
| Console UART and baud rate |  | Hardware |
| DDR configuration and NoC solution file |  | Hardware |
| Programmable logic image names and compatible NoC solution |  | Hardware |
| Delivery format and the XSA hash |  | Hardware |
| Change procedure after the first delivery |  | Both |

From Appendix D of The Embedded AMD EDF Handbook (C. Paul Gordon, Embedded Think). A design, not AMD material, and not tested on a product.
