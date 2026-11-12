#!/bin/bash
# Compile the DMA pool fragments with dtc and run the memory checker of Chapter 19 on each. Output goes to out/.
cd "$(dirname "$0")"; mkdir -p out
{
  for v in "" -misaligned -overlap; do
    dtc -q -I dts -O dtb -o /tmp/dma-top$v.dtb stub-top$v.dts
    echo "\$ dtc -I dts -O dtb -o top.dtb stub-top$v.dts && check-rpu-memory.py top.dtb"
    python3 ../rpu/check-rpu-memory.py /tmp/dma-top$v.dtb; echo "exit status $?"; echo
  done
} > out/dma_memory_check.txt 2>&1
cat out/dma_memory_check.txt
