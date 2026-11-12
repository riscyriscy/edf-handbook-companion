#!/bin/sh
# Test double for a RAUC custom bootloader backend. Boot state lives in a file.
# Arguments are boot names (A, B), as in the bootname= keys of system.conf.
S=${BL_STATE:-/tmp/bl-state}
[ -f "$S" ] || printf 'PRIMARY=A\nSTATE_A=good\nSTATE_B=bad\n' > "$S"
. "$S"
case "$1" in
  get-primary)            echo "$PRIMARY" ;;
  set-primary)            sed -i "s/^PRIMARY=.*/PRIMARY=$2/" "$S" ;;
  get-state)              eval echo "\$STATE_$2" ;;
  set-state)              sed -i "s/^STATE_$2=.*/STATE_$2=$3/" "$S" ;;
  get-current|get-booted) echo A ;;
  *) echo "unknown command $1" >&2; exit 1 ;;
esac
