#!/bin/bash
# Compile the reserved memory fragments with dtc and run the checker on each. Output goes to out/.
cd "$(dirname "$0")"; mkdir -p out
{
  for v in "" -overlap -outside; do
    dtc -q -I dts -O dtb -o /tmp/rpu-top$v.dtb stub-top$v.dts
    echo "\$ dtc -I dts -O dtb -o top.dtb stub-top$v.dts && check-rpu-memory.py top.dtb"
    python3 check-rpu-memory.py /tmp/rpu-top$v.dtb; echo "exit status $?"; echo
  done
} > out/rpu_memory_check.txt 2>&1
cat out/rpu_memory_check.txt
