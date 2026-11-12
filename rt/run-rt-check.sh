#!/bin/bash
# Run the latency gate and the configuration check on the fixtures. Output goes to out/rt_check.txt.
cd "$(dirname "$0")"; mkdir -p out
{
  for f in pass over-budget short; do
    echo "\$ check-cyclictest.py fixtures/$f.txt --max-us 150 --min-samples 3600000"
    ./check-cyclictest.py fixtures/$f.txt --max-us 150 --min-samples 3600000; echo "exit status $?"; echo
  done
  for f in ../meta-handbook/recipes-kernel/linux/files/rt.cfg fixtures/lockdep.config; do
    echo "\$ check-rt-config.sh ${f#../meta-handbook/recipes-kernel/linux/}"
    ./check-rt-config.sh $f; echo "exit status $?"; echo
  done
} > out/rt_check.txt 2>&1
cat out/rt_check.txt
