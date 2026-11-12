#!/bin/bash
# Run the boot checks through labgrid and pytest against the scripted console. Output goes to out/labgrid.txt.
# Needs: pip install labgrid pytest (set PY to the interpreter of that environment).
cd "$(dirname "$0")"; mkdir -p out; PY=${PY:-python3}
{
echo "\$ pip show labgrid | head -2"; $PY -m pip show labgrid 2>/dev/null | head -2
echo
echo '$ pytest --lg-env env.yaml test_boot.py -v'
$PY -m pytest --lg-env env.yaml test_boot.py -v --tb=no -p no:cacheprovider 2>&1 | grep -E "PASSED|FAILED|passed|failed" | sed 's/ \[ *[0-9]*%\]//; s/ in [0-9.]*s//'
echo
echo '$ pytest --lg-env env-panic.yaml test_boot.py -v -x -rf   # the console panics before U-Boot starts'
$PY -m pytest --lg-env env-panic.yaml test_boot.py -v -x --tb=no -rf -p no:cacheprovider 2>&1 | grep -E "PASSED|FAILED|SKIPPED|passed|failed" | sed 's/ \[ *[0-9]*%\]//; s/ in [0-9.]*s//' | cut -c1-120
} > out/labgrid.txt 2>&1
cat out/labgrid.txt
