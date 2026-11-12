#!/bin/bash
# Metadata checks that need no compile. Run inside an initialised build directory.
# Usage: check-metadata.sh <image recipe> <expected package> [<expected package> ...]
set -u
image=$1; shift
fail=0
check() {  # check <description> <command...>
    local what=$1; shift
    if "$@" >/dev/null 2>&1; then echo "PASS  $what"; else echo "FAIL  $what"; fail=$((fail+1)); fi
}
check "all recipes parse"                      bitbake -p
check "image recipe resolves"                  bitbake -g "$image"
for pkg in "$@"; do
    check "IMAGE_INSTALL names $pkg"           bash -c "bitbake-getvar -r $image --value IMAGE_INSTALL | grep -qw $pkg"
done
check "no debug-tweaks in image features"      bash -c "! bitbake-getvar -r $image --value IMAGE_FEATURES | grep -qw debug-tweaks"
check "image has a wic output"                 bash -c "bitbake-getvar -r $image --value IMAGE_FSTYPES | grep -qw wic"
check "layer series match"                     bash -c "! bitbake -p 2>&1 | grep -q 'not compatible with the core layer'"
echo "failures: $fail"
exit $fail
